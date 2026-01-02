import Foundation

struct Device: Identifiable, Codable {
    let id: String
    let name: String
    let type: String
    let status: String
    let position: Position
    let capabilities: [String]
    
    struct Position: Codable {
        let x: Double
        let y: Double
        let z: Double
    }
}

struct ProjectStatus: Codable {
    let totalTasks: Int
    let completedTasks: Int
    let progress: Double
    let tasks: [TaskData]
    let activeAgents: [String]
    
    enum CodingKeys: String, CodingKey {
        case totalTasks = "total_tasks"
        case completedTasks = "completed_tasks"
        case progress
        case tasks
        case activeAgents = "active_agents"
    }
}

struct TaskData: Identifiable, Codable {
    var id: String { text }
    let phase: String
    let text: String
    let status: String
}

struct SystemMetrics: Codable {
    let timestamp: String
    let cpu: Double
    let ram: Double
    let network: String
}

struct FileItem: Identifiable, Codable {
    var id: String { path }
    let name: String
    let path: String
    let is_dir: Bool
    let size: Int
    let type: String
    let category: String // folder, picture, text, app, etc
    let analysis: AnalysisData?
}

struct AnalysisData: Codable {
    let risk_score: Int
    let tags: [String]
    
    enum CodingKeys: String, CodingKey {
        case risk_score = "risk_score"
        case tags
    }
}
