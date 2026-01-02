import SwiftUI

struct SystemStatsPanel: View {
    @EnvironmentObject var backendService: BackendService
    
    var body: some View {
        GlassPanelView(title: "System Stats") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // CPU
                StatBar(label: "CPU", value: backendService.systemMetrics?.cpu ?? 0, color: Theme.Colors.cyanPrimary)
                
                // RAM
                StatBar(label: "RAM", value: backendService.systemMetrics?.ram ?? 0, color: Theme.Colors.purplePrimary)
                
                // Network
                HStack {
                    Text("NETWORK")
                        .font(Theme.Fonts.rajdhani(12))
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(backendService.isConnected ? Theme.Colors.success : Theme.Colors.error)
                            .frame(width: 6, height: 6)
                            .shadow(color: backendService.isConnected ? Theme.Colors.success : Theme.Colors.error, radius: 4)
                        
                        Text(backendService.systemMetrics?.network ?? (backendService.isConnected ? "CONNECTED" : "OFFLINE"))
                            .font(Theme.Fonts.system(12))
                            .foregroundColor(backendService.isConnected ? Theme.Colors.success : Theme.Colors.error)
                    }
                }
                
                // Clock
                HStack {
                    Text("TIME")
                        .font(Theme.Fonts.rajdhani(12))
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    Spacer()
                    
                    Text(Date(), style: .time)
                        .font(Theme.Fonts.system(14))
                        .foregroundColor(Theme.Colors.cyanPrimary)
                }
            }
        }
        // Removed mocked timer
    }
}

struct StatBar: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(Theme.Fonts.rajdhani(12))
                    .foregroundColor(Theme.Colors.textSecondary)
                
                Spacer()
                
                Text("\(Int(value))%")
                    .font(Theme.Fonts.system(12))
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.1))
                        .frame(height: 4)
                    
                    // Fill
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geometry.size.width * (value / 100), height: 4)
                        .shadow(color: color, radius: 4)
                }
            }
            .frame(height: 4)
        }
    }
}

#Preview {
    SystemStatsPanel()
        .frame(width: 300)
        .padding()
        .background(Theme.Colors.background)
}
