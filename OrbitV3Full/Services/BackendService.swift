import Foundation
import Combine

public enum OrbState: String {
    case idle, listening, processing, success, error
}

class BackendService: ObservableObject {
    @Published var isConnected = false
    @Published var devices: [Device] = []
    @Published var projectStatus: ProjectStatus?
    @Published var systemMetrics: SystemMetrics?
    @Published var warfareLogs: [String] = []
    @Published var fileList: [FileItem] = []
    @Published var currentPath: String = ""
    @Published var downloadURL: URL? // For triggering download
    @Published var connectionMode: ConnectionMode = .local
    @Published var orbState: OrbState = .idle
    @Published var audioLevels: [Double] = Array(repeating: 0.5, count: 64)
    
    // Azure 32GB Hub State
    @Published var azureVMRunning: Bool = true  // AntigravityVM starts running
    @Published var azureVMStarting: Bool = false
    @Published var azureVMIP: String = "4.249.17.2"
    @Published var azureVMRAM: Int = 32
    
    enum ConnectionMode {
        case local
        case remote
    }
    
    private var webSocket: URLSessionWebSocketTask?
    private let localURL = "localhost:5556"
    private var remoteURL = "jarvis-beacon.ngrok.io" // Placeholder for Beacon
    
    func connect() {
        let baseURL = connectionMode == .local ? localURL : remoteURL
        guard let url = URL(string: "ws://\(baseURL)/ws") else { return }
        
        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
        receiveMessage()
        
        isConnected = true
        print("✅ Connected to Jarvis backend")
    }
    
    func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        isConnected = false
    }
    
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.receiveMessage() // Continue listening
            case .failure(_):
                print("❌ WebSocket error")
                self?.isConnected = false
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8) else { return }
        
        do {
            let json = try JSONDecoder().decode([String: AnyCodable].self, from: data)
            
            if let event = json["event"]?.value as? String {
                switch event {
                case "device_update":
                    if let devicesData = json["data"]?.value as? [[String: Any]] {
                        parseDevices(from: devicesData)
                    } else if let deviceArray = try? JSONDecoder().decode([Device].self, from: data) {
                        DispatchQueue.main.async {
                            self.devices = deviceArray
                        }
                    }
                    
                case "project_update":
                    if let projectData = try? JSONSerialization.data(withJSONObject: json["data"]?.value ?? [:]),
                       let status = try? JSONDecoder().decode(ProjectStatus.self, from: projectData) {
                        DispatchQueue.main.async {
                            self.projectStatus = status
                        }
                    }
                    
                case "warfare_log":
                    if let message = json["message"]?.value as? String {
                         DispatchQueue.main.async {
                             self.warfareLogs.append(message)
                             // Keep log size manageable
                             if self.warfareLogs.count > 100 {
                                 self.warfareLogs.removeFirst()
                             }
                         }
                    }
                    
                case "system_stats":
                    if let metricsData = try? JSONSerialization.data(withJSONObject: json["data"]?.value ?? [:]),
                       let metrics = try? JSONDecoder().decode(SystemMetrics.self, from: metricsData) {
                        DispatchQueue.main.async {
                            self.systemMetrics = metrics
                        }
                    }

                case "file_list":
                    if let fileData = try? JSONSerialization.data(withJSONObject: json["files"]?.value ?? []),
                       let files = try? JSONDecoder().decode([FileItem].self, from: fileData),
                       let path = json["path"]?.value as? String {
                        DispatchQueue.main.async {
                            self.fileList = files
                            self.currentPath = path
                        }
                    }

                case "batch_complete":
                     if let urlStr = json["url"]?.value as? String,
                        let url = URL(string: "http://localhost:5555" + urlStr) {
                         DispatchQueue.main.async {
                             self.downloadURL = url // Trigger UI to open this
                         }
                     }
                    
                case "audio_waveform":
                     if let dict = json["data"]?.value as? [String: Any],
                        let levels = dict["data"] as? [Double] {
                         DispatchQueue.main.async {
                             self.audioLevels = levels
                         }
                     }

                case "voice_transcription":
                    DispatchQueue.main.async {
                        self.orbState = .processing
                        print("🎤 Voice processing...")
                    }

                case "command_success":
                    DispatchQueue.main.async {
                        self.orbState = .success
                        print("✅ Command success")
                        // Reset to idle after delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self.orbState = .idle
                        }
                    }

                default:
                    break
                }
            }
        } catch {
            print("❌ Failed to parse message: \\(error)")
        }
    }
    
    private func parseDevices(from data: [[String: Any]]) {
        // Manual parsing for complex nested data
        var parsedDevices: [Device] = []
        
for deviceDict in data {
            if let id = deviceDict["id"] as? String,
               let name = deviceDict["name"] as? String,
               let type = deviceDict["type"] as? String,
               let status = deviceDict["status"] as? String,
               let posDict = deviceDict["position"] as? [String: Double],
               let x = posDict["x"], let y = posDict["y"], let z = posDict["z"],
               let capabilities = deviceDict["capabilities"] as? [String] {
                
                let position = Device.Position(x: x, y: y, z: z)
                let device = Device(id: id, name: name, type: type, status: status, position: position, capabilities: capabilities)
                parsedDevices.append(device)
            }
        }
        
        DispatchQueue.main.async {
            self.devices = parsedDevices
        }
    }
    
    func sendVoiceCommand(_ text: String) {
        let message: [String: Any] = ["event": "voice_input", "data": ["text": text]]
        sendJSON(message)
    }
    
    // MARK: - Quadrant Menu Actions
    
    func switchAIModel(_ model: String) {
        let message: [String: Any] = ["event": "switch_ai_model", "data": ["model": model]]
        sendJSON(message)
        print("🤖 Switching to AI model: \(model)")
    }
    
    func startAzureVM() {
        azureVMStarting = true
        let message: [String: Any] = ["event": "azure_start_vm", "data": ["vm_name": "AntigravityVM", "resource_group": "ANTIGRAVITYRG"]]
        sendJSON(message)
        print("🚀 Starting 32GB Hub (AntigravityVM)...")
        
        // Simulate VM start completion (backend will send real status)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.azureVMStarting = false
            self.azureVMRunning = true
        }
    }
    
    func stopAzureVM() {
        azureVMStarting = true
        let message: [String: Any] = ["event": "azure_stop_vm", "data": ["vm_name": "AntigravityVM", "resource_group": "ANTIGRAVITYRG"]]
        sendJSON(message)
        print("⏹️ Stopping 32GB Hub (AntigravityVM)...")
        
        // Simulate VM stop completion (backend will send real status)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.azureVMStarting = false
            self.azureVMRunning = false
        }
    }
    
    func getAzureVMStatus() {
        let message: [String: Any] = ["event": "azure_status", "data": [:]]
        sendJSON(message)
    }
    
    
    func syncGitHub() {
        let message: [String: Any] = ["event": "github_sync", "data": [:]]
        sendJSON(message)
        print("🔄 Syncing with GitHub...")
    }
    
    func startJobMasterScan() {
        let message: [String: Any] = ["event": "start_job_scrape", "data": [:]]
        sendJSON(message)
        print("💼 Starting JobMaster scan...")
    }
    
    func toggleMaintenance() {
        let message: [String: Any] = ["event": "toggle_maintenance", "data": [:]]
        sendJSON(message)
        print("🔧 Toggling maintenance mode...")
    }

    func sendWarfareCommand(_ command: String) {
        let message: [String: Any] = ["event": "warfare_command", "data": ["command": command]]
        sendJSON(message)
        print("⚔️ Sending Warfare command: \(command)")
    }

    func listFiles(_ path: String = "") {
        let message: [String: Any] = ["event": "list_files", "data": ["path": path]]
        sendJSON(message)
    }

    func downloadBatch(_ files: [String]) {
        let message: [String: Any] = ["event": "batch_action", "data": ["files": files, "action": "zip"]]
        sendJSON(message)
    }
    
    // MARK: - Empire Integration (Direct HTTP)
    
    func callEmpireApp(port: Int, endpoint: String, method: String = "GET", body: [String: Any]? = nil) {
        let urlString = "http://localhost:\(port)\(endpoint)"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        print("🌍 Calling Empire App: \(urlString)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ Empire Call Error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.orbState = .error
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                print("✅ Empire Call Success: \(httpResponse.statusCode)")
                DispatchQueue.main.async {
                    self?.orbState = .success
                    // Auto-reset state
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self?.orbState = .idle
                    }
                }
            } else {
                print("⚠️ Empire Call Status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                DispatchQueue.main.async {
                    self?.orbState = .error
                }
            }
        }.resume()
    }
    
    // MARK: - 3D Rotation Controls
    
    func setRotationSpeed(_ speed: Double) {
        NotificationCenter.default.post(name: .rotationSpeedChanged, object: speed)
        print("🎚️ Rotation speed: \(speed)x")
    }
    
    func setRotationDirection(_ direction: Double) {
        NotificationCenter.default.post(name: .rotationDirectionChanged, object: direction)
        print("🌀 Rotation direction: \(direction > 0 ? "clockwise" : "counter-clockwise")")
    }
    
    func reverseRotation() {
        NotificationCenter.default.post(name: .rotationDirectionChanged, object: -1.0)
        print("⇄ Reversed rotation")
    }
    
    func stopRotation() {
        NotificationCenter.default.post(name: .rotationSpeedChanged, object: 0.0)
        print("⏸ Stopped rotation")
    }
    
    private func sendJSON(_ object: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else { return }
        
        webSocket?.send(.string(string)) { error in
            if let error = error {
                print("❌ Send error: \(error)")
            }
        }
    }
}

// Helper for decoding dynamic JSON
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
