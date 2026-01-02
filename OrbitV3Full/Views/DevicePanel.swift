import SwiftUI

struct DevicePanel: View {
    @EnvironmentObject var backendService: BackendService
    
    var body: some View {
        GlassPanelView(title: "Connected Devices") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if backendService.devices.isEmpty {
                    Text("No devices connected")
                        .font(Theme.Fonts.system(11))
                        .foregroundColor(Theme.Colors.textSecondary)
                } else {
                    ForEach(backendService.devices) { device in
                        DeviceRow(device: device)
                    }
                }
            }
        }
    }
}

struct DeviceRow: View {
    let device: Device
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Text(deviceIcon)
                .font(.system(size: 20))
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(Theme.Fonts.rajdhani(12))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text(device.type.capitalized)
                    .font(Theme.Fonts.system(10))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            Spacer()
            
            // Status
            Circle()
                .fill(device.status == "active" ? Theme.Colors.success : Theme.Colors.cyanDim)
                .frame(width: 6, height: 6)
                .shadow(color: device.status == "active" ? Theme.Colors.success : .clear, radius: 3)
        }
        .padding(.vertical, 4)
    }
    
    private var deviceIcon: String {
        switch device.type.lowercased() {
        case "computer": return "💻"
        case "mobile": return "📱"
        case "tablet": return "📱"
        case "speaker": return "🔊"
        case "iot": return "💡"
        default: return "📱"
        }
    }
}

#Preview {
    DevicePanel()
        .frame(width: 350)
        .padding()
        .background(Theme.Colors.background)
        .environmentObject(BackendService())
}
