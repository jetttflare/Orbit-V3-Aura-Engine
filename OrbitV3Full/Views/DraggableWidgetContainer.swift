import SwiftUI
import UniformTypeIdentifiers

struct DraggableWidgetContainer<Content: View>: View {
    let widget: DashboardWidget
    @EnvironmentObject var dashboardManager: DashboardManager
    let content: Content
    
    init(widget: DashboardWidget, @ViewBuilder content: () -> Content) {
        self.widget = widget
        self.content = content()
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            dashboardManager.isEditing ? Theme.Colors.cyanPrimary : Color.clear,
                            lineWidth: 2
                        )
                )
                // Shake animation when editing
                .rotationEffect(
                    dashboardManager.isEditing ? .degrees(Double.random(in: -0.5...0.5)) : .degrees(0)
                )
                .animation(
                    dashboardManager.isEditing ? 
                        Animation.easeInOut(duration: 0.15).repeatForever(autoreverses: true) : 
                        .default,
                    value: dashboardManager.isEditing
                )
            
            if dashboardManager.isEditing {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(Theme.Colors.cyanPrimary)
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
                    .padding(4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle()) // Ensure the whole area is draggable
    }
}
