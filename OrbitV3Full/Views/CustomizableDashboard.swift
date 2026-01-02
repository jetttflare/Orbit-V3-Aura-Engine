import SwiftUI
import UniformTypeIdentifiers

struct CustomizableDashboard: View {
    @StateObject private var dashboardManager = DashboardManager()
    @EnvironmentObject var backendService: BackendService
    @EnvironmentObject var projectManager: ProjectManager
    
    // Grid Configuration - Flexible
    let columns = [
        GridItem(.adaptive(minimum: 300, maximum: 600), spacing: Theme.Spacing.md)
    ]
    
    var body: some View {
        ZStack {
            // Background & Effects layer
            MainBackground()
            
            // Interaction Layer
            VStack {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                        ForEach(dashboardManager.widgets) { widget in
                            DraggableWidgetContainer(widget: widget) {
                                widgetView(for: widget)
                            }
                            // Opacity for drag preview
                            .opacity(dashboardManager.draggingWidget?.id == widget.id ? 0.3 : 1.0)
                            .frame(height: height(for: widget.size))
                            .onDrag {
                                dashboardManager.draggingWidget = widget
                                return NSItemProvider(object: widget.id.uuidString as NSString)
                            }
                            .onDrop(of: [UTType.text], delegate: DashboardDropDelegate(item: widget, items: $dashboardManager.widgets, manager: dashboardManager))
                        }
                    }
                    .padding(Theme.Spacing.lg)
                    .animation(.spring(), value: dashboardManager.widgets)
                }
                
                // HUD Controls
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation {
                            dashboardManager.toggleEditMode()
                        }
                    }) {
                        HStack {
                            Image(systemName: dashboardManager.isEditing ? "checkmark" : "slider.horizontal.3")
                            Text(dashboardManager.isEditing ? "DONE" : "CUSTOMIZE HUD")
                                .font(Theme.Fonts.rajdhani(14))
                        }
                        .padding()
                        .background(Theme.Colors.panelBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Theme.Colors.cyanPrimary, lineWidth: 1)
                        )
                        .foregroundColor(Theme.Colors.cyanPrimary)
                    }
                    .padding()
                }
            }
        }
    }
    
    @ViewBuilder
    func widgetView(for widget: DashboardWidget) -> some View {
        switch widget.type {
        case .systemStats:
            SystemStatsPanel()
        case .projectStatus:
            ProjectPanel()
        case .deviceTracker:
            DevicePanel()
        case .voiceVisualizer:
             VoiceVisualizer()
        case .cyberWarfare:
             CyberWarfarePanel()
        #if os(macOS)
        case .azureUpload:
            AzureUploadPanel()
        case .azureHubControl:
            AzureHubControlPanel()
        case .fileBrowser:
             FileBrowserPanel()
        #endif
        case .empty:
             Spacer()
        default:
             // iOS fallback for macOS-only widgets
             Text("macOS Only")
                 .foregroundColor(.gray)
        }
    }
    
    func height(for size: WidgetSize) -> CGFloat {
        switch size {
        case .small: return 150
        case .medium: return 220
        case .large: return 400
        case .wide: return 100
        }
    }
}

struct MainBackground: View {
    var body: some View {
        ZStack {
             OrbView()
                .opacity(0.15)
                .blur(radius: 20)
        }
    }
}

// Drag and Drop Logic
struct DashboardDropDelegate: DropDelegate {
    let item: DashboardWidget
    @Binding var items: [DashboardWidget]
    let manager: DashboardManager
    
    func dropEntered(info: DropInfo) {
        // Only allow reordering in edit mode
        guard manager.isEditing else { return }
        
        // Ensure we have a dragging widget
        guard let draggingWidget = manager.draggingWidget else { return }
        
        // Don't do anything if hovering over itself
        if draggingWidget.id != item.id {
            // Find indices
            guard let fromIndex = items.firstIndex(where: { $0.id == draggingWidget.id }),
                  let toIndex = items.firstIndex(where: { $0.id == item.id }) else { return }
            
            // Swap items
            withAnimation(.default) {
                items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
        }
    }
    
    func performDrop(info: DropInfo) -> Bool {
        manager.draggingWidget = nil
        return true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}
