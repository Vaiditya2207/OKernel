import Foundation

struct ChatRequest: Codable {
    let message: String
    let context: String?
}

struct ChatResponse: Codable {
    let reply: String
}

class SyscoreClient: NSObject, URLSessionDataDelegate {
    static let shared = SyscoreClient()
    private let baseURL = "http://127.0.0.1:3001"
    
    // Streaming state
    private var streamBuffer = ""
    private var onToken: ((String) -> Void)?
    private var onComplete: (() -> Void)?
    private var onError: ((String) -> Void)?
    private var activeSession: URLSession?
    private var activeTask: URLSessionDataTask?
    
    override init() {
        super.init()
    }
    
    // Legacy non-streaming method
    func askCopilot(message: String, context: String?, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/chat") else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = ChatRequest(message: message, context: context)
        request.httpBody = try? JSONEncoder().encode(payload)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion("Syscore API Error: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            if let result = try? JSONDecoder().decode(ChatResponse.self, from: data) {
                completion(result.reply)
            } else {
                completion("Failed to decode response from Syscore.")
            }
        }.resume()
    }
    
    // Streaming SSE method — fires onToken per chunk, onComplete when done
    func streamChat(
        message: String,
        context: String?,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (String) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/api/chat/stream") else {
            onError("Invalid URL")
            return
        }
        
        self.onToken = onToken
        self.onComplete = onComplete
        self.onError = onError
        self.streamBuffer = ""
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        
        let payload = ChatRequest(message: message, context: context)
        request.httpBody = try? JSONEncoder().encode(payload)
        
        // Create a session with delegate to handle streaming
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        activeSession = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        activeTask = activeSession?.dataTask(with: request)
        activeTask?.resume()
    }
    
    func cancelStream() {
        activeTask?.cancel()
        activeTask = nil
        activeSession?.invalidateAndCancel()
        activeSession = nil
    }
    
    // MARK: - URLSessionDataDelegate
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        streamBuffer += chunk
        
        // Process complete SSE lines
        while let lineEnd = streamBuffer.range(of: "\n") {
            let line = String(streamBuffer[streamBuffer.startIndex..<lineEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            streamBuffer = String(streamBuffer[lineEnd.upperBound...])
            
            if line == "data: [DONE]" {
                onComplete?()
                return
            }
            
            if line.hasPrefix("data: ") {
                let jsonStr = String(line.dropFirst(6))
                if let jsonData = jsonStr.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    if let text = json["text"] as? String {
                        onToken?(text)
                    }
                    if let error = json["error"] as? String {
                        onError?(error)
                    }
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            if (error as NSError).code != NSURLErrorCancelled {
                onError?("Connection error: \(error.localizedDescription)")
            }
        }
        onComplete?()
        activeSession = nil
        activeTask = nil
    }
    
    // MARK: - Agent: Execute Command
    
    func executeCommand(command: String, completion: @escaping (String) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/agent/exec") else {
            completion("Error: Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let payload: [String: String] = ["command": command]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil else {
                    completion("Error: \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let output = json["output"] as? String {
                    completion(output)
                } else {
                    completion(String(data: data, encoding: .utf8) ?? "Unknown response")
                }
            }
        }.resume()
    }
}
