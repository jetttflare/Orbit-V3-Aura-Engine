import SwiftUI
import SceneKit

struct MainDashboard: View {
    @EnvironmentObject var backendService: BackendService
    @State private var rotationSpeed: Double = 1.0
    @State private var rotationDirection: Double = 1.0
    
    var body: some View {
        ZStack {
            // 3D Background Layer
            GeometryReader { geometry in
                // AI Orb (center)
                OrbView()
                    .frame(width: 500, height: 500)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .rotation3DEffect(
                        .degrees(rotationSpeed * rotationDirection * 360),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .animation(.linear(duration: 20 / rotationSpeed).repeatForever(autoreverses: false), value: rotationSpeed)
            }
            
            // HUD Overlay Layer
            VStack {
                // Top Bar
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    // System Stats Panel (left)
                    SystemStatsPanel()
                        .frame(width: 300)
                    
                    Spacer()
                    
                    // Project Status Panel (right)
                    ProjectPanel()
                        .frame(width: 300)
                }
                .padding(Theme.Spacing.lg)
                
                Spacer()
                
                // Bottom Bar
                HStack {
                    // Azure Upload Panel (bottom-left) - macOS Only
                    #if os(macOS)
                    AzureUploadPanel()
                        .frame(width: 350)
                    #else
                    // iOS placeholder
                    EmptyView()
                    #endif
                    
                    Spacer()
                    
                    // Voice Visualizer (bottom-center)
                    VoiceVisualizer()
                        .frame(width: 600, height: 80)
                }
                .padding(Theme.Spacing.lg)
            }
            
            // Quadrant Menu Overlay (all 4 corners)
            QuadrantOverlay()
        }
        .onReceive(NotificationCenter.default.publisher(for: .rotationSpeedChanged)) { notification in
            if let speed = notification.object as? Double {
                rotationSpeed = speed
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .rotationDirectionChanged)) { notification in
            if let direction = notification.object as? Double {
                rotationDirection = direction
            }
        }
    }
}

// Notification names for 3D control
extension Notification.Name {
    static let rotationSpeedChanged = Notification.Name("rotationSpeedChanged")
    static let rotationDirectionChanged = Notification.Name("rotationDirectionChanged")
}

#Preview {
    MainDashboard()
        .frame(width: 1200, height: 800)
        .environmentObject(BackendService())
        .environmentObject(ProjectManager())
}
