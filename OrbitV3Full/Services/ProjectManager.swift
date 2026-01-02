import Foundation
import Combine

class ProjectManager: ObservableObject {
    @Published var tasks: [ProjectTask] = []
    @Published var progress: Double = 0.0
    
    private let taskFileURL: URL
    private var fileMonitor: DispatchSourceFileSystemObject?
    
    init(taskPath: String = "~/.gemini/antigravity/brain/4b4c0389-4a1c-4501-ba92-b2955f9e2616/task.md") {
        let expandedPath = NSString(string: taskPath).expandingTildeInPath
        self.taskFileURL = URL(fileURLWithPath: expandedPath)
        
        loadTasks()
        setupFileMonitoring()
    }
    
    deinit {
        fileMonitor?.cancel()
    }
    
    private func loadTasks() {
        guard FileManager.default.fileExists(atPath: taskFileURL.path),
              let content = try? String(contentsOf: taskFileURL) else {
            print("❌ Task file not found at: \\(taskFileURL.path)")
            return
        }
        
        var parsedTasks: [ProjectTask] = []
        var currentPhase = ""
        
        content.enumerateLines { line, _ in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("## ") {
                currentPhase = String(trimmed.dropFirst(3))
            } else if trimmed.hasPrefix("- [") {
                let statusChar = trimmed[trimmed.index(trimmed.startIndex, offsetBy: 3)]
                let text = String(trimmed.dropFirst(6))
                
                let status: TaskStatus
                if statusChar == "x" {
                    status = .completed
                } else if statusChar == "/" {
                    status = .inProgress
                } else {
                    status = .pending
                }
                
                parsedTasks.append(ProjectTask(phase: currentPhase, text: text, status: status))
            }
        }
        
        DispatchQueue.main.async {
            self.tasks = parsedTasks
            let completed = parsedTasks.filter { $0.status == .completed }.count
            self.progress = parsedTasks.isEmpty ? 0 : Double(completed) / Double(parsedTasks.count)
            print("✅ Loaded \\(parsedTasks.count) tasks, \\(Int(self.progress * 100))% complete")
        }
    }
    
    private func setupFileMonitoring() {
        guard FileManager.default.fileExists(atPath: taskFileURL.path) else { return }
        
        let fileDescriptor = open(taskFileURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }
        
        fileMonitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: DispatchQueue.main
        )
        
        fileMonitor?.setEventHandler { [weak self] in
            print("📝 Task file updated, reloading...")
            self?.loadTasks()
        }
        
        fileMonitor?.setCancelHandler {
            close(fileDescriptor)
        }
        
        fileMonitor?.resume()
        print("👀 Monitoring task file for changes")
    }
}

struct ProjectTask: Identifiable {
    let id = UUID()
    let phase: String
    let text: String
    let status: TaskStatus
}

enum TaskStatus {
    case pending, inProgress, completed
}
