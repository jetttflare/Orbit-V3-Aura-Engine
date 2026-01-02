import SwiftUI

struct GlassPanelView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @State private var isMinimized = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Header
            HStack {
                Text(title)
                    .font(Theme.Fonts.orbitron(14))
                    .foregroundColor(Theme.Colors.cyanPrimary)
                    .textCase(.uppercase)
                
                Spacer()
                
                Button(action: {
                    withAnimation(Theme.Animation.fast) {
                        isMinimized.toggle()
                    }
                }) {
                    Image(systemName: isMinimized ? "plus" : "minus")
                        .foregroundColor(Theme.Colors.cyanPrimary)
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.plain)
                .help(isMinimized ? "Expand" : "Minimize")
            }
            
            // Content
            if !isMinimized {
                content
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Theme.Colors.cyanGlow,
                                    Theme.Colors.purpleGlow
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Theme.Colors.cyanGlow, radius: 10, x: 0, y: 0)
    }
}

#Preview {
    GlassPanelView(title: "System Stats") {
        VStack(alignment: .leading, spacing: 8) {
            Text("CPU: 45%")
            Text("RAM: 60%")
            Text("Network: Online")
        }
        .foregroundColor(Theme.Colors.textSecondary)
    }
    .frame(width: 300)
    .padding()
    .background(Theme.Colors.background)
}
