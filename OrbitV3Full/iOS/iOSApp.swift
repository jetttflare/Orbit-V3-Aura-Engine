#if os(iOS)
import SwiftUI

// MARK: - iOS Specific Entry Point
@main
struct JarvisIronManiOSApp: App {
    @StateObject private var backendService = BackendService()
    @StateObject private var projectManager = ProjectManager()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            iOSMainDashboard()
                .environmentObject(backendService)
                .environmentObject(projectManager)
                .preferredColorScheme(.dark)
                .onAppear {
                    backendService.connect()
                }
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                if !backendService.isConnected {
                    backendService.connect()
                }
            case .background:
                // Keep connection alive for background updates
                break
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}

// MARK: - iOS Optimized Dashboard
struct iOSMainDashboard: View {
    @EnvironmentObject var backendService: BackendService
    @State private var selectedQuadrant: QuadrantPosition?
    @State private var showingFullscreen = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0, green: 0.05, blue: 0.15),
                        Color(red: 0, green: 0.02, blue: 0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // 3D Orb (simplified for iOS)
                if PlatformFeatures.supports3DRotation {
                    OrbView()
                        .frame(width: min(geometry.size.width * 0.5, 300),
                               height: min(geometry.size.width * 0.5, 300))
                        .position(x: geometry.size.width / 2,
                                  y: geometry.size.height / 2)
                }
                
                // Status Bar (top)
                VStack {
                    iOSStatusBar()
                        .padding(.horizontal)
                        .padding(.top, 10)
                    
                    Spacer()
                    
                    // Voice Waveform (bottom)
                    iOSVoiceBar()
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                }
                
                // Quadrant Corners (iOS optimized)
                iOSQuadrantOverlay(geometry: geometry)
                
                // Fullscreen overlay
                if showingFullscreen, let quadrant = selectedQuadrant {
                    iOSFullscreenPanel(quadrant: quadrant) {
                        withAnimation(.spring()) {
                            showingFullscreen = false
                            selectedQuadrant = nil
                        }
                    }
                }
            }
        }
        .statusBar(hidden: true)
    }
}

// MARK: - iOS Status Bar
struct iOSStatusBar: View {
    @EnvironmentObject var backendService: BackendService
    
    var body: some View {
        HStack {
            // Connection status
            HStack(spacing: 6) {
                Circle()
                    .fill(backendService.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(backendService.isConnected ? "CONNECTED" : "OFFLINE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // System metrics
            if let metrics = backendService.systemMetrics {
                HStack(spacing: 15) {
                    iOSMetricPill(label: "CPU", value: "\(Int(metrics.cpu))%")
                    iOSMetricPill(label: "RAM", value: "\(Int(metrics.ram))%")
                }
            }
            
            Spacer()
            
            // Time
            Text(Date(), style: .time)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(Color.cyan.opacity(0.9))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - iOS Metric Pill
struct iOSMetricPill: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color.cyan)
        }
    }
}

// MARK: - iOS Voice Bar
struct iOSVoiceBar: View {
    @State private var waveformLevels: [CGFloat] = Array(repeating: 0.2, count: 30)
    
    var body: some View {
        VStack(spacing: 8) {
            // Waveform
            HStack(spacing: 2) {
                ForEach(0..<waveformLevels.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan, Color.blue],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 4, height: waveformLevels[index] * 40)
                        .animation(.easeInOut(duration: 0.1), value: waveformLevels[index])
                }
            }
            .frame(height: 50)
            
            // Listening indicator
            Text("🎤 Listening...")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear {
            animateWaveform()
        }
    }
    
    private func animateWaveform() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation {
                waveformLevels = waveformLevels.map { _ in CGFloat.random(in: 0.1...1.0) }
            }
        }
    }
}

// MARK: - iOS Quadrant Overlay
struct iOSQuadrantOverlay: View {
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            // Top-Left
            iOSQuadrantButton(position: .topLeft)
                .position(x: PlatformScaling.cornerPadding + PlatformScaling.quadrantCircleSize/2,
                          y: PlatformSafeArea.topInset + 80 + PlatformScaling.quadrantCircleSize/2)
            
            // Top-Right
            iOSQuadrantButton(position: .topRight)
                .position(x: geometry.size.width - PlatformScaling.cornerPadding - PlatformScaling.quadrantCircleSize/2,
                          y: PlatformSafeArea.topInset + 80 + PlatformScaling.quadrantCircleSize/2)
            
            // Bottom-Left
            iOSQuadrantButton(position: .bottomLeft)
                .position(x: PlatformScaling.cornerPadding + PlatformScaling.quadrantCircleSize/2,
                          y: geometry.size.height - 100 - PlatformScaling.quadrantCircleSize/2)
            
            // Bottom-Right
            iOSQuadrantButton(position: .bottomRight)
                .position(x: geometry.size.width - PlatformScaling.cornerPadding - PlatformScaling.quadrantCircleSize/2,
                          y: geometry.size.height - 100 - PlatformScaling.quadrantCircleSize/2)
        }
    }
}

// MARK: - iOS Quadrant Button
struct iOSQuadrantButton: View {
    let position: QuadrantPosition
    @State private var isExpanded = false
    @State private var scrollIndex = 0
    @EnvironmentObject var backendService: BackendService
    
    private var options: [QuadrantOption] {
        QuadrantOption.options(for: position)
    }
    
    var body: some View {
        ZStack {
            // Circular button
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.1), Color.blue.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: PlatformScaling.quadrantCircleSize,
                       height: PlatformScaling.quadrantCircleSize)
                .overlay(
                    Circle()
                        .stroke(Color.cyan.opacity(0.5), lineWidth: 2)
                )
                .shadow(color: Color.cyan.opacity(0.3), radius: 15)
            
            VStack(spacing: 2) {
                Text(position.icon)
                    .font(.system(size: PlatformScaling.iconSize))
                
                Text(position.rawValue)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan.opacity(0.9))
            }
        }
        .onTapGesture {
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 10)
                .onEnded { value in
                    let direction = value.translation.height > 0 ? 1 : -1
                    scrollIndex = (scrollIndex + direction + options.count) % options.count
                    
                    // Light haptic
                    let generator = UISelectionFeedbackGenerator()
                    generator.selectionChanged()
                }
        )
        .sheet(isPresented: $isExpanded) {
            iOSQuadrantSheet(position: position)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - iOS Quadrant Sheet
struct iOSQuadrantSheet: View {
    let position: QuadrantPosition
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var backendService: BackendService
    @State private var activeIndex = 0
    
    private var options: [QuadrantOption] {
        QuadrantOption.options(for: position)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                        Button {
                            activeIndex = index
                            handleOptionSelect(option.action)
                            
                            // Haptic
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        } label: {
                            HStack {
                                Text(option.icon)
                                    .font(.system(size: 24))
                                
                                VStack(alignment: .leading) {
                                    Text(option.name)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    Text(option.status)
                                        .font(.system(size: 12))
                                        .foregroundColor(index == activeIndex ? .yellow : .green)
                                }
                                
                                Spacer()
                                
                                if index == activeIndex {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.cyan)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(index == activeIndex ? Color.orange.opacity(0.3) : Color.blue.opacity(0.2))
                            )
                        }
                    }
                }
                .padding()
            }
            .background(Color.black.opacity(0.9))
            .navigationTitle(position.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func handleOptionSelect(_ action: String) {
        switch action {
        case "groq", "gemini", "deepseek", "grok":
            backendService.switchAIModel(action)
        case "azure-start":
            backendService.startAzureVM()
        case "github-sync":
            backendService.syncGitHub()
        case "jobmaster":
            backendService.startJobMasterScan()
        default:
            break
        }
    }
}

// MARK: - iOS Fullscreen Panel
struct iOSFullscreenPanel: View {
    let quadrant: QuadrantPosition
    let onClose: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
            
            VStack {
                Text(quadrant.title)
                    .font(.title2)
                    .foregroundColor(.cyan)
                
                // Content would go here
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.9))
            )
        }
    }
}
#endif
