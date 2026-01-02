#if os(macOS)
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var backendService: BackendService
    @EnvironmentObject var projectManager: ProjectManager
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.05, green: 0.05, blue: 0.05) // Semantic Theme replacement
                .ignoresSafeArea()
            
            TabView(selection: $selectedTab) {
                // Placeholder for Dashboard if CustomDashboard not found in scope or shared
                Text("Dashboard")
                    .tabItem { Label("Dashboard", systemImage: "gauge") }
                    .tag(0)
                
                // Placeholder for Editor
                Text("Editor")
                    .tabItem { Label("Studio", systemImage: "slider.horizontal.3") }
                    .tag(1)
            }
        }
        .frame(minWidth: 1200, minHeight: 800)
        .onAppear {
            backendService.connect()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(BackendService())
        .environmentObject(ProjectManager())
}
#endif
