use bollard::Docker;
use bollard::container::{Config, CreateContainerOptions, LogOutput, LogsOptions};
use bollard::models::HostConfig;
use futures::StreamExt;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::{Mutex, broadcast};
use uuid::Uuid;
use async_trait::async_trait;

#[derive(Clone, Debug, PartialEq, Eq, Hash, serde::Deserialize, serde::Serialize)]
pub enum Language {
    Python,
    Cpp,
}

impl Language {
    fn image_name(&self) -> &str {
        match self {
            Language::Python => "okernel/python-runner",
            Language::Cpp => "okernel/cpp-runner",
        }
    }
}

#[async_trait]
pub trait ContainerManagerTrait: Send + Sync + 'static {
    async fn health_check(&self) -> Result<(), String>;
    async fn execute(&self, lang: Language, code: String) -> Result<String, String>;
    async fn subscribe(&self, job_id: &str) -> Option<broadcast::Receiver<String>>;
}

#[derive(Clone)]
pub struct ContainerManager {
    docker: Docker,
    job_channels: Arc<Mutex<HashMap<String, broadcast::Sender<String>>>>,
}

impl ContainerManager {
    pub fn new() -> Result<Self, bollard::errors::Error> {
        let docker = Docker::connect_with_local_defaults()?;
        Ok(Self {
            docker,
            job_channels: Arc::new(Mutex::new(HashMap::new())),
        })
    }

    async fn cleanup_container(&self, id: &str) -> Result<(), bollard::errors::Error> {
        self.docker.remove_container(id, Some(bollard::container::RemoveContainerOptions {
            force: true,
            ..Default::default()
        })).await
    }

    pub async fn build_image(&self, lang: Language) -> Result<(), String> {
        use bollard::image::BuildImageOptions;
        
        // Try to find the docker directory in several locations
        let path = match lang {
            Language::Python => "docker/python",
            Language::Cpp => "docker/cpp",
        };
        
        let mut build_path = None;
        
        // 1. Check relative to current working directory
        if std::path::Path::new(path).exists() {
            build_path = Some(path.to_string());
        } 
        // 2. Check in syscore/ prefix (local dev)
        else if std::path::Path::new("syscore").join(path).exists() {
            build_path = Some(format!("syscore/{}", path));
        }
        // 3. Check relative to executable (production)
        else if let Ok(exe_path) = std::env::current_exe() {
            if let Some(exe_dir) = exe_path.parent() {
                let p = exe_dir.join(path);
                if p.exists() {
                    build_path = Some(p.to_string_lossy().to_string());
                }
            }
        }

        let build_path = build_path.ok_or_else(|| {
            let cwd = std::env::current_dir().map(|p| p.to_string_lossy().to_string()).unwrap_or_else(|_| "unknown".to_string());
            format!("Build directory for {:?} not found. Looked for {} relative to CWD ({}) and executable.", lang, path, cwd)
        })?;
        
        tracing::info!("Building image for {:?} from {}", lang, build_path);


        let output = std::process::Command::new("tar")
            .arg("-czf")
            .arg("-")
            .arg("--exclude=.DS_Store")
            .arg("-C")
            .arg(&build_path)
            .arg(".")
            .output()
            .map_err(|e| format!("Tar execution failed: {}", e))?;
            
        if !output.status.success() {
            return Err(format!("Tar failed: {:?}", output.stderr));
        }
        
        let build_options = BuildImageOptions {
            t: lang.image_name(),
            networkmode: "host",
            ..Default::default()
        };
        
        let mut stream = self.docker.build_image(
            build_options, 
            None, 
            Some(output.stdout.into())
        );
        
        while let Some(msg) = stream.next().await {
            match msg {
                Ok(info) => {
                    if let Some(s) = info.stream {
                         if !s.trim().is_empty() {
                             tracing::debug!("Build: {}", s.trim());
                         }
                    }
                    if let Some(e) = info.error {
                        return Err(format!("Build failed: {}", e));
                    }
                },
                Err(e) => return Err(format!("Build stream error: {}", e)),
            }
        }
        
        tracing::info!("Successfully built image for {:?}", lang);
        Ok(())
    }

    async fn ensure_image(&self, lang: Language) -> Result<(), String> {
        let image_name = lang.image_name();
        if self.docker.inspect_image(image_name).await.is_err() {
            tracing::warn!("Image {} not found, attempting to build...", image_name);
            self.build_image(lang).await?;
        }
        Ok(())
    }
}

#[async_trait]
impl ContainerManagerTrait for ContainerManager {
    /// Verifies Docker connection and ability to run containers
    async fn health_check(&self) -> Result<(), String> {
        tracing::info!("Verifying Docker connection...");
        
        // 1. Check version/ping
        let version = self.docker.version().await.map_err(|e| format!("Docker ping failed: {}", e))?;
        tracing::info!("Docker connected: Version {}", version.version.unwrap_or_default());

        // 2. Check if we can list images (basic permission check)
        self.docker.list_images::<String>(None).await.map_err(|e| format!("Failed to list images (permission error?): {}", e))?;

        Ok(())
    }

    async fn subscribe(&self, job_id: &str) -> Option<broadcast::Receiver<String>> {
        let channels = self.job_channels.lock().await;
        channels.get(job_id).map(|sender| sender.subscribe())
    }

    /// Executes code by spawning a bespoke container, running it, collecting output, and destroying it.
    async fn execute(&self, lang: Language, code: String) -> Result<String, String> {
        let job_id = Uuid::new_v4().to_string();
        tracing::info!("[Job {}] Starting execution for {:?}", job_id, lang);

        // 1. Ensure Image
        self.ensure_image(lang.clone()).await?;

        // 2. Prepare Command
        let cmd = match lang {
            Language::Python => crate::profiler::python::PythonProfiler::wrap_command(&code),
            Language::Cpp => crate::profiler::cpp::CppProfiler::wrap_command(&code),
        };

        // 3. Configure Container (Ephemeral)
        let host_config = HostConfig {
            memory: Some(256 * 1024 * 1024), // 256 MB limit
            nano_cpus: Some(1_000_000_000), // 1 CPU
            network_mode: Some("none".to_string()), // No network access for security
            auto_remove: Some(false), // We remove manually to safely collect logs first
            ..Default::default()
        };

        // The container will run the command and then exit (because python script finishes)
        let config = Config {
            image: Some(lang.image_name()),
            cmd: Some(cmd.iter().map(|s| s.as_str()).collect()),
            attach_stdout: Some(true),
            attach_stderr: Some(true),
            tty: Some(false), // Non-interactive
            host_config: Some(host_config),
            ..Default::default()
        };

        let container_name = format!("okernel-job-{}", job_id);

        // 4. Create Container
        tracing::debug!("[Job {}] Spawning container {}", job_id, container_name);
        let id = self.docker.create_container(
            Some(CreateContainerOptions { 
                name: container_name.clone(),
                platform: None, 
            }),
            config,
        ).await.map_err(|e| format!("Failed to create container: {}", e))?.id;

        // 5. Start Container
        self.docker.start_container::<String>(&id, None).await
            .map_err(|e| {
                // Cleanup if start fails
                // Note: we can't await cleanup here without potentially making it recursive or messy if not careful, 
                // but we are in async context so it's fine.
                format!("Failed to start container: {}", e)
            })?;

        tracing::info!("[Job {}] Container started via Spawn->Run strategy", job_id);

        // 6. Wait for execution to finish
        let wait_res = self.docker.wait_container::<String>(&id, None).next().await;
        
        if let Some(Ok(res)) = wait_res {
             tracing::debug!("[Job {}] Container exited with code {}", job_id, res.status_code);
        } else {
             tracing::warn!("[Job {}] Wait failed or container crashed specifically", job_id);
        }
        
        // 7. Collect Logs (Trace Events)
        let logs_opts = LogsOptions::<String> {
            stdout: true,
            stderr: true,
            ..Default::default()
        };
        
        let mut trace_events = Vec::new();
        let mut log_stream = self.docker.logs(&id, Some(logs_opts));

        while let Some(msg) = log_stream.next().await {
            match msg {
                Ok(LogOutput::StdOut { message }) | Ok(LogOutput::StdErr { message }) => {
                    let log_str = String::from_utf8_lossy(&message);
                    for line in log_str.split('\n') {
                         if line.is_empty() { continue; }
                         if line.contains("__SYSCORE_EVENT__") {
                            if let Some(json_str) = line.split("__SYSCORE_EVENT__").nth(1) {
                                if let Ok(event) = serde_json::from_str::<serde_json::Value>(json_str) {
                                    trace_events.push(event);
                                }
                            }
                        } else {
                             // Capture standard output meant for user
                            let log_event = serde_json::json!({
                                "type": "Stdout",
                                "content": line
                            });
                            trace_events.push(log_event);
                        }
                    }
                },
                Ok(_) => {}, // Console/Stream types
                Err(e) => tracing::warn!("[Job {}] Log retrieval error: {}", job_id, e),
            }
        }

        // 8. Cleanup
        let _ = self.cleanup_container(&id).await;

        // 9. Upload Results
        if !trace_events.is_empty() {
            tracing::info!("[Job {}] Uploading {} trace events", job_id, trace_events.len());
            if let Err(e) = crate::server::trace_store::upload_trace(&job_id, trace_events).await {
                 return Err(format!("Trace upload failed: {}", e));
            }
        } else {
            tracing::warn!("[Job {}] No output collected from container", job_id);
        }

        Ok(job_id)
    }
}

#[derive(Clone)]
pub struct MockContainerManager;

#[async_trait]
impl ContainerManagerTrait for MockContainerManager {
    async fn health_check(&self) -> Result<(), String> {
        Ok(())
    }

    async fn execute(&self, _lang: Language, _code: String) -> Result<String, String> {
        Ok("mock-job-id".to_string())
    }

    async fn subscribe(&self, _job_id: &str) -> Option<broadcast::Receiver<String>> {
        None
    }
}
