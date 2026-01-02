import SwiftUI

struct CyberWarfarePanel: View {
    @EnvironmentObject var backendService: BackendService
    @State private var isRunning = false
    @State private var targetIP = "localhost:8080"
    
    var body: some View {
        GlassPanelView(title: "WAR GAMES SIMULATION") {
            VStack(spacing: 0) {
                // Header / Target Info
                HStack {
                    Label("TARGET: \(targetIP)", systemImage: "target")
                        .font(Theme.Fonts.codeMono(size: 12))
                        .foregroundColor(Theme.Colors.crimsonText)
                    
                    Spacer()
                    
                    if isRunning {
                        Text("ACTIVE")
                            .font(Theme.Fonts.codeMono(size: 10))
                            .padding(4)
                            .background(Theme.Colors.crimsonPrimary)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                            .transition(.opacity)
                    }
                }
                .padding(.bottom, 8)
                
                // Attack Visualizer (The "Screen")
                ZStack {
                    // Background grid
                    Color.black.opacity(0.8)
                    
                    // Live Real-Time Logs from Backend
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(backendService.warfareLogs.enumerated()), id: \.offset) { index, log in
                                    Text(log)
                                        .font(Theme.Fonts.codeMono(size: 10))
                                        .foregroundColor(colorForLog(log))
                                        .id(index)
                                }
                            }
                            .padding(8)
                        }
                        .onChange(of: backendService.warfareLogs.count) { count in
                             if count > 0 {
                                 withAnimation {
                                     proxy.scrollTo(count - 1, anchor: .bottom)
                                 }
                             }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Theme.Colors.crimsonPrimary.opacity(0.5), lineWidth: 1)
                )
                
                // Footer Controls
                HStack {
                    Button(action: toggleSimulation) {
                        HStack {
                            Image(systemName: isRunning ? "stop.fill" : "play.fill")
                            Text(isRunning ? "ABORT" : "INITIATE LIVE FIRE")
                        }
                        .font(Theme.Fonts.techBold(size: 12))
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(isRunning ? Theme.Colors.crimsonPrimary.opacity(0.8) : Theme.Colors.cyanPrimary.opacity(0.8))
                        .cornerRadius(4)
                    }
                }
                .padding(.top, 8)
            }
            .padding(12)
        }
    }
    
    private func toggleSimulation() {
        isRunning.toggle()
        if isRunning {
            // Send Real Command to Python Backend
            backendService.sendWarfareCommand("start")
        } else {
            // Logic to stop/abort if supported
            // For now, toggle UI state
        }
    }
    
    private func colorForLog(_ log: String) -> Color {
        if log.contains("[SUCCESS]") || log.contains("[PWNED]") { return .green }
        if log.contains("[FAIL]") || log.contains("[ERROR]") { return .red }
        if log.contains("[VULN]") { return .orange }
        if log.contains("[WEAPON]") { return .yellow }
        return .white
    }
}
