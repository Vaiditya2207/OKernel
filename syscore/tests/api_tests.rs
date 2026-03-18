use axum::http::StatusCode;
use axum_test::TestServer;
use serde_json::json;
use syscore::create_app;
use syscore::docker::manager::MockContainerManager;
use std::sync::Arc;

async fn get_test_server() -> TestServer {
    let container_manager = Arc::new(MockContainerManager);
    let app = create_app(container_manager);
    TestServer::new(app).unwrap()
}

#[tokio::test]
async fn test_health_check() {
    let server = get_test_server().await;
    let response = server.get("/health").await;
    response.assert_status(StatusCode::OK);
    assert!(response.text().contains("SysCore Backend: ONLINE"));
}

#[tokio::test]
async fn test_simulate_tick() {
    let server = get_test_server().await;
    
    let payload = json!({
        "currentTime": 0,
        "processes": [
            {
                "id": 1,
                "name": "P1",
                "arrivalTime": 0,
                "burstTime": 5,
                "remainingTime": 5,
                "priority": 1,
                "state": "WAITING",
                "color": "#ff0000",
                "startTime": null,
                "completionTime": null,
                "waitingTime": 0,
                "turnaroundTime": 0
            }
        ],
        "readyQueue": [],
        "runningProcessId": null,
        "completedProcessIds": [],
        "ganttChart": [],
        "algorithm": "FCFS",
        "timeQuantum": 2,
        "quantumRemaining": 2,
        "isPlaying": false,
        "speed": 1
    });

    let response = server
        .post("/api/simulate/cpu/tick")
        .json(&payload)
        .await;

    response.assert_status(StatusCode::OK);
    let body: serde_json::Value = response.json();
    
    // In FCFS at t=0, P1 should arrive and start running
    assert_eq!(body["currentTime"], 1);
    assert_eq!(body["runningProcessId"], 1);
    assert_eq!(body["processes"][0]["remainingTime"], 4);
    assert_eq!(body["processes"][0]["state"], "RUNNING");
}

#[tokio::test]
async fn test_execute_mock() {
    let server = get_test_server().await;
    
    let payload = json!({
        "language": "python",
        "code": "print('hello')"
    });

    let response = server
        .post("/api/execute")
        .json(&payload)
        .await;

    response.assert_status(StatusCode::OK);
    let body: serde_json::Value = response.json();
    assert_eq!(body["status"], "success");
    assert_eq!(body["output"], "mock-job-id");
}
