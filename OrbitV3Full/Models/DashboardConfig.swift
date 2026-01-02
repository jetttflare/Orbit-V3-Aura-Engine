import Foundation
import SwiftUI

enum WidgetType: String, Codable, CaseIterable {
    case systemStats
    case projectStatus
    case deviceTracker
    case azureUpload
    case azureHubControl  // NEW: 32GB Hub start/stop toggle
    case voiceVisualizer
    case cyberWarfare // Educational Module
    case fileBrowser // File Manager
    case empty // For spacing if needed

    var id: String {
        return self.rawValue
    }
}

struct DashboardWidget: Identifiable, Codable, Equatable {
    let id: UUID
    var type: WidgetType
    var title: String
    var size: WidgetSize
    var order: Int
    
    init(type: WidgetType, title: String? = nil, size: WidgetSize = .medium, order: Int = 0) {
        self.id = UUID()
        self.type = type
        self.title = title ?? type.rawValue.capitalized
        self.size = size
        self.order = order
    }
}

enum WidgetSize: String, Codable {
    case small   // 1x1
    case medium  // 2x1 (Horizontal)
    case large   // 2x2
    case wide    // 4x1 (Full width)
}

class DashboardManager: ObservableObject {
    @Published var widgets: [DashboardWidget] = []
    @Published var isEditing: Bool = false
    @Published var draggingWidget: DashboardWidget? = nil
    
    init() {
        loadLayout()
    }
    
    func loadLayout() {
        // Default Information Dense Layout
        // We'll arrange them in a way that maximizes visibility
        self.widgets = [
            DashboardWidget(type: .systemStats, title: "SYSTEM STATUS", size: .medium, order: 0),
            DashboardWidget(type: .azureHubControl, title: "32GB HUB", size: .small, order: 1),
            DashboardWidget(type: .projectStatus, title: "MISSION LOG", size: .medium, order: 2),
            DashboardWidget(type: .deviceTracker, title: "DEVICE TRACKER", size: .large, order: 3),
            DashboardWidget(type: .azureUpload, title: "UPLINK", size: .small, order: 4),
            DashboardWidget(type: .voiceVisualizer, title: "AUDIO WAVEFORM", size: .wide, order: 5),
            DashboardWidget(type: .cyberWarfare, title: "CYBER WARFARE", size: .medium, order: 6)
        ]
    }
    
    func updateOrder(from source: IndexSet, to destination: Int) {
        widgets.move(fromOffsets: source, toOffset: destination)
        // Re-assign order indices if we were persisting to DB
        for (index, _) in widgets.enumerated() {
            widgets[index].order = index
        }
    }
    
    func toggleEditMode() {
        withAnimation(.spring()) {
            isEditing.toggle()
        }
    }
}
