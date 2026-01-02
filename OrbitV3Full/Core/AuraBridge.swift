// AuraBridge.swift
// Bridge component connecting AURA WebSocket to JarvisIronMan Swift app
// Refactored to use native URLSessionWebSocketTask instead of Starscream

import Foundation

/// AURA Bridge Protocol - Implement in JarvisCore
@MainActor
public protocol AuraBridgeDelegate: AnyObject {
    func auraBridge(_ bridge: AuraBridge, didReceiveCommand command: AuraCommand)
    func auraBridge(_ bridge: AuraBridge, didUpdateMetrics metrics: AuraMetrics)
    func auraBridge(_ bridge: AuraBridge, connectionStateChanged connected: Bool)
}

/// Metrics from AURA system
public struct AuraMetrics: Codable {
    public let cpu: Double
    public let mem: Double
    public let timestamp: Int64
    public let uptime: Int64
}

/// Command from AURA
public struct AuraCommand: Codable {
    public let type: String
    public let cmd: String?
    public let response: String?
    public let timestamp: Int64?
}

/// Bridge to AURA WebSocket API (using native URLSessionWebSocketTask)
public class AuraBridge: NSObject {
    
    public static let shared = AuraBridge()
    
    public weak var delegate: AuraBridgeDelegate?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var isConnected = false
    private var reconnectWorkItem: DispatchWorkItem?
    
    // Configuration
    private let auraHost: String
    private let auraPort: Int
    
    public init(host: String = "localhost", port: Int = 3001) {
        self.auraHost = host
        self.auraPort = port
        super.init()
    }
    
    // MARK: - Connection Management
    
    public func connect() {
        guard webSocketTask == nil else { return }
        
        let urlString = "ws://\(auraHost):\(auraPort)"
        guard let url = URL(string: urlString) else {
            print("[AuraBridge] Invalid URL: \(urlString)")
            return
        }
        
        urlSession = URLSession(configuration: .default)
        webSocketTask = urlSession?.webSocketTask(with: url)
        webSocketTask?.resume()
        
        isConnected = true
        print("[AuraBridge] Connecting to \(urlString)...")
        
        Task { @MainActor in
            delegate?.auraBridge(self, connectionStateChanged: true)
        }
        
        receiveMessage()
    }
    
    public func disconnect() {
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        
        Task { @MainActor in
            delegate?.auraBridge(self, connectionStateChanged: false)
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                self?.receiveMessage() // Continue listening
                
            case .failure(let error):
                print("[AuraBridge] WebSocket error: \(error)")
                self?.isConnected = false
                self?.webSocketTask = nil
                Task { @MainActor in
                    self?.delegate?.auraBridge(self!, connectionStateChanged: false)
                }
                self?.scheduleReconnect()
            }
        }
    }
    
    private func scheduleReconnect() {
        reconnectWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.connect()
        }
        reconnectWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: workItem)
    }
    
    // MARK: - Commands
    
    public func sendCommand(_ command: String) {
        guard isConnected else {
            print("[AuraBridge] Not connected, cannot send command")
            return
        }
        
        let payload: [String: Any] = [
            "type": "command",
            "cmd": command,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let json = String(data: data, encoding: .utf8) {
            webSocketTask?.send(.string(json)) { error in
                if let error = error {
                    print("[AuraBridge] Send error: \(error)")
                }
            }
        }
    }
    
    public func evolve() {
        sendCommand("aura:evolve")
    }
    
    public func getStatus() {
        sendCommand("aura:status")
    }
    
    public func setMetricsInterval(_ ms: Int) {
        sendCommand("aura:set-interval \(ms)")
    }
    
    public func simulateTouch(x: Int, y: Int) {
        guard isConnected else { return }
        
        let payload: [String: Any] = ["type": "touch", "x": x, "y": y]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let json = String(data: data, encoding: .utf8) {
            webSocketTask?.send(.string(json)) { error in
                if let error = error {
                    print("[AuraBridge] Send error: \(error)")
                }
            }
        }
    }
    
    // MARK: - Message Handling
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let type = json?["type"] as? String ?? ""
            
            switch type {
            case "metrics":
                if let metricsData = json?["data"] as? [String: Any],
                   let metricsJson = try? JSONSerialization.data(withJSONObject: metricsData),
                   let metrics = try? JSONDecoder().decode(AuraMetrics.self, from: metricsJson) {
                    Task { @MainActor in
                        delegate?.auraBridge(self, didUpdateMetrics: metrics)
                    }
                }
                
            case "command:response", "command":
                if let cmdJson = try? JSONSerialization.data(withJSONObject: json ?? [:]),
                   let command = try? JSONDecoder().decode(AuraCommand.self, from: cmdJson) {
                    Task { @MainActor in
                        delegate?.auraBridge(self, didReceiveCommand: command)
                    }
                }
                
            default:
                print("[AuraBridge] Unknown message type: \(type)")
            }
        } catch {
            print("[AuraBridge] Parse error: \(error)")
        }
    }
}
