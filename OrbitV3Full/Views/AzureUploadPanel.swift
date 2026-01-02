#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct AzureUploadPanel: View {
    @State private var isTargeted = false
    @State private var uploadStatus = "Idle"
    @State private var showFilePicker = false
    
    var body: some View {
        GlassPanelView(title: "Cloud Uplink (Azure)") {
            VStack(spacing: 12) {
                // Status Area
                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: statusColor, radius: 4)
                    
                    Text(uploadStatus.uppercased())
                        .font(Theme.Fonts.rajdhani(12))
                        .foregroundColor(statusColor)
                    
                    Spacer()
                    
                    Text("32GB A-TIER")
                        .font(Theme.Fonts.system(10))
                        .foregroundColor(Theme.Colors.cyanDim)
                }
                
                // Drop Zone / Button
                Button(action: { showFilePicker = true }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundColor(isTargeted ? Theme.Colors.success : Theme.Colors.cyanDim)
                            .background(Theme.Colors.cyanPrimary.opacity(0.05))
                        
                        VStack(spacing: 6) {
                            Text("☁️")
                                .font(.system(size: 24))
                            Text("CLICK TO UPLOAD FILES")
                                .font(Theme.Fonts.rajdhani(11))
                                .foregroundColor(Theme.Colors.cyanPrimary)
                        }
                    }
                    .frame(height: 80)
                }
                .buttonStyle(.plain)
                .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                    guard let provider = providers.first else { return false }
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url = url {
                            DispatchQueue.main.async {
                                uploadFile(url: url)
                            }
                        }
                    }
                    return true
                }
                .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.content]) { result in
                    switch result {
                    case .success(let url):
                        uploadFile(url: url)
                    case .failure(let error):
                        print("File selection error: \(error)")
                    }
                }
                
                // Launch TUI Button
                Button(action: launchTUI) {
                    HStack {
                        Text("📺 LAUNCH COMMAND DECK")
                            .font(Theme.Fonts.rajdhani(12))
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Theme.Colors.cyanPrimary.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Theme.Colors.cyanPrimary, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .foregroundColor(Theme.Colors.cyanPrimary)
            }
        }
    }
    
    var statusColor: Color {
        switch uploadStatus {
        case "Uploading...": return Theme.Colors.warning
        case "Upload Complete": return Theme.Colors.success
        case "Error": return Color.red
        default: return Theme.Colors.cyanPrimary
        }
    }
    
    func launchTUI() {
        let primaryPath = "/Users/jlow/Desktop/🚀 Antigravity Hub.command"
        let fallbackPath = "/Users/jlow/Desktop/🚀 Connect to 32GB Hub.command"
        
        let scriptPath = FileManager.default.fileExists(atPath: primaryPath) ? primaryPath : fallbackPath
        let url = URL(fileURLWithPath: scriptPath)
        NSWorkspace.shared.open(url)
    }
    
    func uploadFile(url: URL) {
        uploadStatus = "Uploading..."
        
        // Handle security scoping
        let gotAccess = url.startAccessingSecurityScopedResource()
        
        DispatchQueue.global(qos: .userInitiated).async {
            let remotePath = "jlow@4.249.17.2:~/uploads/"
            // Ensure dir exists
            _ = shell("ssh jlow@4.249.17.2 'mkdir -p ~/uploads'")
            
            // SCP
            let scpCmd = "scp \"\(url.path)\" \(remotePath)"
            let result = shell(scpCmd)
            
            if gotAccess {
                url.stopAccessingSecurityScopedResource()
            }
            
            DispatchQueue.main.async {
                if result == 0 {
                    uploadStatus = "Upload Complete"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        uploadStatus = "Idle"
                    }
                } else {
                    uploadStatus = "Error"
                }
            }
        }
    }
    
    func shell(_ command: String) -> Int32 {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", command]
        task.launch()
        task.waitUntilExit()
        return task.terminationStatus
    }
}
#endif
