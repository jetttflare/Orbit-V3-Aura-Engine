// JarvisCore.swift
// Core shared functionality for cross-platform Jarvis IronMan

import Foundation

/// Network service for connecting to Python backend
public class JarvisConnection: ObservableObject {
    public static let shared = JarvisConnection()
    
    @Published public var isConnected: Bool = false
    @Published public var lastError: String? = nil
    
    public init() {}
    
    public func connect(to url: String) async throws {
        // Connection logic handled by BackendService
    }
}

/// System status model
public struct SystemStatus: Codable {
    public var cpu: Double
    public var ram: Double
    public var network: String
    
    public init(cpu: Double = 0, ram: Double = 0, network: String = "offline") {
        self.cpu = cpu
        self.ram = ram
        self.network = network
    }
}

/// AI Model representation
public struct AIModelInfo: Codable, Identifiable {
    public var id: String { name }
    public var name: String
    public var provider: String
    public var tier: String
    public var isActive: Bool
    
    public init(name: String, provider: String, tier: String, isActive: Bool = false) {
        self.name = name
        self.provider = provider
        self.tier = tier
        self.isActive = isActive
    }
}
