import SwiftUI

// MARK: - Quadrant Position
enum QuadrantPosition: String, CaseIterable {
    case topLeft = "AI"
    case topRight = "SYS"
    case bottomLeft = "DATA"
    case bottomRight = "VOICE"
    
    var icon: String {
        switch self {
        case .topLeft: return "🤖"
        case .topRight: return "⚙️"
        case .bottomLeft: return "📊"
        case .bottomRight: return "🎤"
        }
    }
    
    var title: String {
        switch self {
        case .topLeft: return "AI Model Selection"
        case .topRight: return "System Control"
        case .bottomLeft: return "Analytics & Monitoring"
        case .bottomRight: return "Voice Control"
        }
    }
}

// MARK: - Quadrant Option
struct QuadrantOption: Identifiable, Hashable {
    let id = UUID()
    let icon: String
    let name: String
    var status: String
    let action: String
    
    static func options(for position: QuadrantPosition) -> [QuadrantOption] {
        switch position {
        case .topLeft:
            return [
                QuadrantOption(icon: "⚡", name: "Groq Llama 3.3", status: "ACTIVE", action: "groq"),
                QuadrantOption(icon: "🔍", name: "Virtual PullUp", status: "READY", action: "empire-01"),
                QuadrantOption(icon: "🎨", name: "Landing Page", status: "READY", action: "empire-04"),
                QuadrantOption(icon: "✍️", name: "Writing Asst", status: "READY", action: "empire-09"),
                QuadrantOption(icon: "🛍️", name: "MCP Market", status: "READY", action: "empire-13")
            ]
        case .topRight:
            return [
                QuadrantOption(icon: "🚁", name: "Drone Tech", status: "READY", action: "empire-05"),
                QuadrantOption(icon: "🥗", name: "Meal Planner", status: "READY", action: "empire-08"),
                QuadrantOption(icon: "💼", name: "Job Tracker", status: "IDLE", action: "empire-10"),
                QuadrantOption(icon: "📄", name: "Resume Opt", status: "READY", action: "empire-11"),
                QuadrantOption(icon: "🚀", name: "32GB Hub", status: "RUNNING", action: "azure-start"),
                QuadrantOption(icon: "🔧", name: "Maintenance", status: "ENABLED", action: "maintenance")
            ]
        case .bottomLeft:
            return [
                QuadrantOption(icon: "💰", name: "Finance Advisor", status: "READY", action: "empire-06"),
                QuadrantOption(icon: "📜", name: "Contract Analyzer", status: "READY", action: "empire-07"),
                QuadrantOption(icon: "🎙️", name: "LilBit Factory", status: "READY", action: "empire-02"),
                QuadrantOption(icon: "📊", name: "Performance", status: "LIVE", action: "performance")
            ]
        case .bottomRight:
            return [
                QuadrantOption(icon: "☎️", name: "Phone Reception", status: "LISTENING", action: "empire-03"),
                QuadrantOption(icon: "🎬", name: "Clip Generator", status: "READY", action: "empire-12"),
                QuadrantOption(icon: "📧", name: "Cold Emailer", status: "READY", action: "empire-14"),
                QuadrantOption(icon: "🆘", name: "Support Agent", status: "READY", action: "empire-15"),
                QuadrantOption(icon: "🍎", name: "Siri Bridge", status: "ACTIVE", action: "siri")
            ]
        }
    }
}

// MARK: - Quadrant Circle Button
struct QuadrantCircle: View {
    let position: QuadrantPosition
    let isExpanded: Bool
    @Binding var scrollIndex: Int
    let options: [QuadrantOption]
    
    var body: some View {
        ZStack {
            // Rotating border
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.6), Color.cyan.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2
                )
                .frame(width: 90, height: 90)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
            
            // Main circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: isExpanded
                            ? [Color.orange.opacity(0.2), Color.red.opacity(0.2)]
                            : [Color.cyan.opacity(0.1), Color.blue.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .overlay(
                    Circle()
                        .stroke(
                            isExpanded ? Color.orange.opacity(0.8) : Color.cyan.opacity(0.5),
                            lineWidth: 2
                        )
                )
                .shadow(color: isExpanded ? Color.orange.opacity(0.6) : Color.cyan.opacity(0.3), radius: 20)
            
            // Content
            VStack(spacing: 2) {
                Text(position.icon)
                    .font(.system(size: 28))
                
                Text(options.isEmpty ? position.rawValue : options[scrollIndex].name.prefix(8).description)
                    .font(Theme.Fonts.label)
                    .foregroundColor(Color.cyan.opacity(0.9))
            }
        }
        .scaleEffect(isExpanded ? 0.9 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
    }
}

// MARK: - Quadrant Option Row
struct QuadrantOptionRow: View {
    let option: QuadrantOption
    let isActive: Bool
    let onTap: () -> Void
    
    private var statusColor: Color {
        isActive ? Color.yellow.opacity(0.9) : Color.green.opacity(0.9)
    }
    
    private var statusBackgroundColor: Color {
        isActive ? Color.yellow.opacity(0.1) : Color.green.opacity(0.1)
    }
    
    private var statusBorderColor: Color {
        isActive ? Color.yellow.opacity(0.3) : Color.green.opacity(0.3)
    }
    
    private var rowBackgroundColor: Color {
        isActive ? Color.orange.opacity(0.3) : Color.blue.opacity(0.3)
    }
    
    private var rowBorderColor: Color {
        isActive ? Color.orange.opacity(0.6) : Color.cyan.opacity(0.2)
    }
    
    var body: some View {
        Button(action: onTap) {
            rowContent
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var rowContent: some View {
        HStack(spacing: 12) {
            Text(option.icon)
                .font(.system(size: 20))
                .shadow(color: Color.cyan.opacity(0.6), radius: 5)
            
            Text(option.name)
                .font(Theme.Fonts.body)
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
            
            statusBadge
        }
        .padding(12)
        .background(rowBackground)
        .shadow(color: isActive ? Color.orange.opacity(0.4) : Color.cyan.opacity(0.3), radius: isActive ? 20 : 0)
    }
    
    private var statusBadge: some View {
        Text(option.status)
            .font(Theme.Fonts.label)
            .foregroundColor(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(statusBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(statusBorderColor, lineWidth: 1)
                    )
            )
    }
    
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(rowBackgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(rowBorderColor, lineWidth: 1)
            )
    }
}

// MARK: - Quadrant Expanded Panel
struct QuadrantExpandedPanel: View {
    let position: QuadrantPosition
    @Binding var options: [QuadrantOption]
    @Binding var activeIndex: Int
    let isFullscreen: Bool
    let onFullscreenToggle: () -> Void
    let onOptionSelect: (Int) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Header
            HStack {
                Text(position.title)
                    .font(Theme.Fonts.headline)
                    .foregroundColor(Color.cyan.opacity(0.9))
                
                Spacer()
                
                Button(action: onFullscreenToggle) {
                    Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 20))
                        .foregroundColor(Color.cyan.opacity(0.9))
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.cyan.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 10)
            
            Divider()
                .background(Color.cyan.opacity(0.3))
            
            // Options
            if isFullscreen {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: 12) {
                    ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                        QuadrantOptionRow(option: option, isActive: index == activeIndex) {
                            onOptionSelect(index)
                        }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                        QuadrantOptionRow(option: option, isActive: index == activeIndex) {
                            onOptionSelect(index)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(
                    LinearGradient(
                        colors: isFullscreen
                            ? [Color.black.opacity(0.15), Color.black.opacity(0.15)]
                            : [Color(red: 0, green: 0.08, blue: 0.16).opacity(0.95), Color(red: 0, green: 0.04, blue: 0.12).opacity(0.95)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.cyan.opacity(isFullscreen ? 0.8 : 0.4), lineWidth: isFullscreen ? 3 : 2)
                )
                .shadow(color: Color.cyan.opacity(isFullscreen ? 0.6 : 0.2), radius: isFullscreen ? 100 : 30)
        )
        .blur(radius: isFullscreen ? 0 : 0)
    }
}

// MARK: - Quadrant Menu View
struct QuadrantMenuView: View {
    let position: QuadrantPosition
    @State private var isExpanded = false
    @State private var isFullscreen = false
    @State private var scrollIndex = 0
    @State private var activeIndex = 0
    @State private var options: [QuadrantOption]
    @EnvironmentObject var backendService: BackendService
    
    init(position: QuadrantPosition) {
        self.position = position
        _options = State(initialValue: QuadrantOption.options(for: position))
    }
    
    var body: some View {
        ZStack {
            // Fullscreen backdrop
            if isFullscreen {
                Color.black.opacity(0.2)
                    .blur(radius: 2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring()) {
                            isFullscreen = false
                        }
                    }
            }
            
            // Main content
            if isFullscreen {
                fullscreenContent
            } else {
                regularContent
            }
        }
    }
    
    private var regularContent: some View {
        HStack(spacing: 10) {
            if position == .topRight || position == .bottomRight {
                if isExpanded {
                    QuadrantExpandedPanel(
                        position: position,
                        options: $options,
                        activeIndex: $activeIndex,
                        isFullscreen: isFullscreen,
                        onFullscreenToggle: { withAnimation(.spring()) { isFullscreen = true } },
                        onOptionSelect: handleOptionSelect
                    )
                    .frame(width: 320)
                    .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .scale.combined(with: .opacity)))
                }
            }
            
            QuadrantCircle(position: position, isExpanded: isExpanded, scrollIndex: $scrollIndex, options: options)
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isExpanded {
                                let direction = value.translation.height > 0 ? 1 : -1
                                if abs(value.translation.height) > 20 {
                                    scrollIndex = (scrollIndex + direction + options.count) % options.count
                                }
                            }
                        }
                )
            
            if position == .topLeft || position == .bottomLeft {
                if isExpanded {
                    QuadrantExpandedPanel(
                        position: position,
                        options: $options,
                        activeIndex: $activeIndex,
                        isFullscreen: isFullscreen,
                        onFullscreenToggle: { withAnimation(.spring()) { isFullscreen = true } },
                        onOptionSelect: handleOptionSelect
                    )
                    .frame(width: 320)
                    .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .scale.combined(with: .opacity)))
                }
            }
        }
    }
    
    private var fullscreenContent: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                QuadrantExpandedPanel(
                    position: position,
                    options: $options,
                    activeIndex: $activeIndex,
                    isFullscreen: true,
                    onFullscreenToggle: { withAnimation(.spring()) { isFullscreen = false } },
                    onOptionSelect: handleOptionSelect
                )
                .frame(maxWidth: 1000, maxHeight: 600)
                
                Spacer()
            }
            
            Spacer()
            
            // Corner circle in fullscreen
            HStack {
                if position == .bottomRight || position == .topRight {
                    Spacer()
                }
                
                QuadrantCircle(position: position, isExpanded: true, scrollIndex: $scrollIndex, options: options)
                    .onTapGesture {
                        withAnimation(.spring()) {
                            isFullscreen = false
                            isExpanded = false
                        }
                    }
                    .padding()
                
                if position == .bottomLeft || position == .topLeft {
                    Spacer()
                }
            }
        }
    }
    
    private func handleOptionSelect(_ index: Int) {
        activeIndex = index
        let action = options[index].action
        
        // Empire Integration
        if action.starts(with: "empire-") {
            let appID = action.replacingOccurrences(of: "empire-", with: "")
            let portBase = 5000
            if let idInt = Int(appID) {
                let port = portBase + idInt
                // Toggle/Ping logic: Check health
                options[index].status = "CHECKING..."
                backendService.callEmpireApp(port: port, endpoint: "/health")
                // Optimistic UI update
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.options[index].status = "ACTIVE"
                }
                return
            }
        }
        
        // Execute action via backend service
        switch action {
        case "groq", "gemini", "deepseek", "grok":
            backendService.switchAIModel(action)
        case "azure-start":
            backendService.startAzureVM()
            // Update status in options
            options[index].status = "STARTING..."
        case "azure-stop":
            backendService.stopAzureVM()
            options[index].status = "STOPPING..."
        case "github-sync":
            backendService.syncGitHub()
        case "jobmaster":
            backendService.startJobMasterScan()
        default:
            print("Action: \(action)")
        }
    }
}

// MARK: - Quadrant Overlay
struct QuadrantOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Top-Left (AI)
                VStack {
                    HStack {
                        QuadrantMenuView(position: .topLeft)
                            .padding(.top, 80)
                            .padding(.leading, 20)
                        Spacer()
                    }
                    Spacer()
                }
                
                // Top-Right (System)
                VStack {
                    HStack {
                        Spacer()
                        QuadrantMenuView(position: .topRight)
                            .padding(.top, 80)
                            .padding(.trailing, 20)
                    }
                    Spacer()
                }
                
                // Bottom-Left (Analytics)
                VStack {
                    Spacer()
                    HStack {
                        QuadrantMenuView(position: .bottomLeft)
                            .padding(.bottom, 120)
                            .padding(.leading, 20)
                        Spacer()
                    }
                }
                
                // Bottom-Right (Voice)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        QuadrantMenuView(position: .bottomRight)
                            .padding(.bottom, 120)
                            .padding(.trailing, 20)
                    }
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        QuadrantOverlay()
    }
    .frame(width: 1200, height: 800)
    .environmentObject(BackendService())
}
