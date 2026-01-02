#if os(macOS)
import SwiftUI

@main
struct JarvisIronManApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var backendService = BackendService()
    @StateObject private var projectManager = ProjectManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(backendService)
                .environmentObject(projectManager)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Jarvis") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            .applicationName: "Jarvis Iron Man",
                            .applicationVersion: "1.0.0",
                            .credits: NSAttributedString(string: "The future of AI")
                        ]
                    )
                }
            }
        }
    }
}
#endif
