#if os(macOS)
import SwiftUI

struct AzureHubControlPanel: View {
    @EnvironmentObject var backendService: BackendService
    @State private var showingConnectionSheet = false
    
    var body: some View {
        GlassPanelView(title: "32GB COMPUTE HUB") {
            VStack(spacing: 16) {
                // Status Header
                HStack {
                    // Status Indicator
                    Circle()
                        .fill(statusColor)
                        .frame(width: 12, height: 12)
                        .shadow(color: statusColor, radius: 6)
                        .overlay(
                            Circle()
                                .stroke(statusColor.opacity(0.5), lineWidth: 2)
                                .scaleEffect(backendService.azureVMStarting ? 1.5 : 1.0)
                                .opacity(backendService.azureVMStarting ? 0 : 1)
                                .animation(.easeOut(duration: 1).repeatForever(autoreverses: false), value: backendService.azureVMStarting)
                        )
                    
                    Text(statusText)
                        .font(Theme.Fonts.rajdhani(14))
                        .fontWeight(.bold)
                        .foregroundColor(statusColor)
                    
                    Spacer()
                    
                    // RAM Badge
                    HStack(spacing: 4) {
                        Image(systemName: "memorychip")
                            .font(.system(size: 10))
                        Text("\(backendService.azureVMRAM)GB")
                            .font(Theme.Fonts.system(10))
                    }
                    .foregroundColor(Theme.Colors.cyanPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Theme.Colors.cyanPrimary.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .stroke(Theme.Colors.cyanPrimary.opacity(0.4), lineWidth: 1)
                            )
                    )
                }
                
                // VM Details
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("VM:")
                            .font(Theme.Fonts.label)
                            .foregroundColor(Theme.Colors.cyanDim)
                        Spacer()
                        Text("AntigravityVM")
                            .font(Theme.Fonts.system(11))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    HStack {
                        Text("IP:")
                            .font(Theme.Fonts.label)
                            .foregroundColor(Theme.Colors.cyanDim)
                        Spacer()
                        Text(backendService.azureVMIP)
                            .font(Theme.Fonts.system(11))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    HStack {
                        Text("REGION:")
                            .font(Theme.Fonts.label)
                            .foregroundColor(Theme.Colors.cyanDim)
                        Spacer()
                        Text("westus3")
                            .font(Theme.Fonts.system(11))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.3))
                )
                
                // Control Buttons
                HStack(spacing: 12) {
                    // Start/Stop Toggle
                    Button(action: {
                        if backendService.azureVMRunning {
                            backendService.stopAzureVM()
                        } else {
                            backendService.startAzureVM()
                        }
                    }) {
                        HStack {
                            if backendService.azureVMStarting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.warning))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: backendService.azureVMRunning ? "stop.fill" : "play.fill")
                            }
                            Text(buttonText)
                                .font(Theme.Fonts.rajdhani(11))
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(buttonColor.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(buttonColor, lineWidth: 1)
                        )
                        .foregroundColor(buttonColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(backendService.azureVMStarting)
                    
                    // SSH Connect Button
                    Button(action: { launchSSH() }) {
                        HStack {
                            Image(systemName: "terminal")
                            Text("SSH")
                                .font(Theme.Fonts.rajdhani(11))
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.Colors.cyanPrimary.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Theme.Colors.cyanPrimary, lineWidth: 1)
                        )
                        .foregroundColor(Theme.Colors.cyanPrimary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!backendService.azureVMRunning)
                    .opacity(backendService.azureVMRunning ? 1.0 : 0.5)
                }
            }
        }
    }
    
    var statusColor: Color {
        if backendService.azureVMStarting {
            return Theme.Colors.warning
        } else if backendService.azureVMRunning {
            return Theme.Colors.success
        } else {
            return Color.red.opacity(0.8)
        }
    }
    
    var statusText: String {
        if backendService.azureVMStarting {
            return backendService.azureVMRunning ? "STOPPING..." : "STARTING..."
        } else if backendService.azureVMRunning {
            return "ONLINE"
        } else {
            return "OFFLINE"
        }
    }
    
    var buttonText: String {
        if backendService.azureVMStarting {
            return "PLEASE WAIT"
        } else if backendService.azureVMRunning {
            return "STOP HUB"
        } else {
            return "START HUB"
        }
    }
    
    var buttonColor: Color {
        if backendService.azureVMStarting {
            return Theme.Colors.warning
        } else if backendService.azureVMRunning {
            return Color.red.opacity(0.8)
        } else {
            return Theme.Colors.success
        }
    }
    
    func launchSSH() {
        let primaryPath = "/Users/jlow/Desktop/🚀 Antigravity Hub.command"
        let fallbackPath = "/Users/jlow/Desktop/🚀 Connect to 32GB Hub.command"
        
        let primaryURL = URL(fileURLWithPath: primaryPath)
        let fallbackURL = URL(fileURLWithPath: fallbackPath)
        
        if FileManager.default.fileExists(atPath: primaryPath) {
            NSWorkspace.shared.open(primaryURL)
        } else {
            NSWorkspace.shared.open(fallbackURL)
        }
    }
}
#endif
