import SwiftUI

// MARK: - Platform Detection
enum Platform {
    case macOS
    case iOS
    case iPadOS
    case tvOS
    case watchOS
    case windows
    case linux
    case android
    
    static var current: Platform {
        #if os(macOS)
        return .macOS
        #elseif os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .iPadOS
        }
        return .iOS
        #elseif os(tvOS)
        return .tvOS
        #elseif os(watchOS)
        return .watchOS
        #elseif os(Windows)
        return .windows
        #elseif os(Linux)
        return .linux
        #else
        return .iOS // Default fallback
        #endif
    }
    
    var name: String {
        switch self {
        case .macOS: return "macOS"
        case .iOS: return "iOS"
        case .iPadOS: return "iPadOS"
        case .tvOS: return "tvOS"
        case .watchOS: return "watchOS"
        case .windows: return "Windows"
        case .linux: return "Linux"
        case .android: return "Android"
        }
    }
}

// MARK: - Platform-Specific UI Scaling
struct PlatformScaling {
    static var quadrantCircleSize: CGFloat {
        switch Platform.current {
        case .macOS: return 80
        case .iPadOS: return 90
        case .iOS: return 60
        case .watchOS: return 40
        case .tvOS: return 120
        default: return 80
        }
    }
    
    static var panelWidth: CGFloat {
        switch Platform.current {
        case .macOS: return 320
        case .iPadOS: return 350
        case .iOS: return 280
        case .watchOS: return 150
        case .tvOS: return 400
        default: return 320
        }
    }
    
    static var fontSize: CGFloat {
        switch Platform.current {
        case .macOS: return 14
        case .iPadOS: return 16
        case .iOS: return 13
        case .watchOS: return 10
        case .tvOS: return 20
        default: return 14
        }
    }
    
    static var iconSize: CGFloat {
        switch Platform.current {
        case .macOS: return 28
        case .iPadOS: return 32
        case .iOS: return 24
        case .watchOS: return 16
        case .tvOS: return 40
        default: return 28
        }
    }
    
    static var cornerPadding: CGFloat {
        switch Platform.current {
        case .macOS: return 20
        case .iPadOS: return 30
        case .iOS: return 15
        case .watchOS: return 5
        case .tvOS: return 50
        default: return 20
        }
    }
}

// MARK: - Platform-Specific Gestures
struct PlatformGestures {
    static var supportsHover: Bool {
        #if os(macOS)
        return true
        #elseif os(tvOS)
        return true // Focus-based hover
        #else
        return false
        #endif
    }
    
    static var supportsDrag: Bool {
        #if os(watchOS)
        return false
        #else
        return true
        #endif
    }
    
    static var supportsScroll: Bool {
        #if os(watchOS)
        return true // Digital Crown
        #elseif os(tvOS)
        return false // Use focus navigation
        #else
        return true
        #endif
    }
    
    static var supportsHaptics: Bool {
        #if os(iOS)
        return true
        #elseif os(watchOS)
        return true
        #else
        return false
        #endif
    }
}

// MARK: - Platform-Specific Touch/Click Handling
#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit

extension View {
    func platformTapGesture(action: @escaping () -> Void) -> some View {
        self.onTapGesture(perform: action)
    }
    
    func platformHapticFeedback() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }
}
#endif

#if os(macOS)
import AppKit

extension View {
    func platformTapGesture(action: @escaping () -> Void) -> some View {
        self.onTapGesture(perform: action)
    }
    
    func platformHapticFeedback() {
        // macOS: Use NSHapticFeedbackManager if available
        if #available(macOS 10.11, *) {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }
    }
}
#endif

// MARK: - Platform-Specific Animations
struct PlatformAnimations {
    static var springResponse: Double {
        switch Platform.current {
        case .watchOS: return 0.2 // Faster on watch
        case .tvOS: return 0.5 // Slower for TV
        default: return 0.3
        }
    }
    
    static var springDamping: Double {
        switch Platform.current {
        case .tvOS: return 0.6
        default: return 0.7
        }
    }
    
    static func spring() -> Animation {
        .spring(response: springResponse, dampingFraction: springDamping)
    }
}

// MARK: - Platform-Specific Colors
struct PlatformColors {
    static var primaryCyan: Color {
        #if os(tvOS)
        // Brighter for TV viewing distance
        return Color(red: 0, green: 1, blue: 1)
        #else
        return Color(red: 0, green: 0.9, blue: 0.9)
        #endif
    }
    
    static var backgroundBlur: Double {
        switch Platform.current {
        case .macOS: return 20
        case .iOS, .iPadOS: return 15
        case .tvOS: return 30
        case .watchOS: return 5
        default: return 20
        }
    }
}

// MARK: - Platform-Specific Layout Modifiers
struct PlatformAdaptiveLayout: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(
                minWidth: Platform.current == .watchOS ? 150 : nil,
                maxWidth: Platform.current == .watchOS ? 200 : .infinity
            )
    }
}

extension View {
    func platformAdaptive() -> some View {
        modifier(PlatformAdaptiveLayout())
    }
}

// MARK: - Platform Feature Flags
struct PlatformFeatures {
    static var supports3DRotation: Bool {
        #if os(watchOS)
        return false // Too heavy for watch
        #else
        return true
        #endif
    }
    
    static var supportsFullscreen: Bool {
        #if os(watchOS)
        return false
        #else
        return true
        #endif
    }
    
    static var supportsVoiceControl: Bool {
        #if os(tvOS)
        return false // Use Siri remote instead
        #else
        return true
        #endif
    }
    
    static var supportsAzureVM: Bool {
        switch Platform.current {
        case .macOS, .iOS, .iPadOS:
            return true
        default:
            return false
        }
    }
    
    static var quadrantCount: Int {
        switch Platform.current {
        case .watchOS: return 2 // Simplified UI
        case .tvOS: return 4 // Full UI
        default: return 4
        }
    }
}

// MARK: - Safe Area Handling
struct PlatformSafeArea {
    static var topInset: CGFloat {
        #if os(iOS)
        return UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0
        #else
        return 0
        #endif
    }
    
    static var bottomInset: CGFloat {
        #if os(iOS)
        return UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0
        #else
        return 0
        #endif
    }
}

// MARK: - Platform-Specific Quadrant Positioning
extension QuadrantPosition {
    var offset: CGSize {
        let padding = PlatformScaling.cornerPadding
        let size = PlatformScaling.quadrantCircleSize
        
        switch self {
        case .topLeft:
            return CGSize(width: padding + size/2, height: padding + size/2 + PlatformSafeArea.topInset)
        case .topRight:
            return CGSize(width: -(padding + size/2), height: padding + size/2 + PlatformSafeArea.topInset)
        case .bottomLeft:
            return CGSize(width: padding + size/2, height: -(padding + size/2 + PlatformSafeArea.bottomInset))
        case .bottomRight:
            return CGSize(width: -(padding + size/2), height: -(padding + size/2 + PlatformSafeArea.bottomInset))
        }
    }
}

// MARK: - Build Configuration
#if DEBUG
let isDebugBuild = true
#else
let isDebugBuild = false
#endif

#if targetEnvironment(simulator)
let isSimulator = true
#else
let isSimulator = false
#endif

// MARK: - Performance Optimizations
struct PlatformPerformance {
    static var maxAnimationFPS: Int {
        switch Platform.current {
        case .watchOS: return 30
        case .tvOS: return 60
        default: return 60
        }
    }
    
    static var use3DEffects: Bool {
        switch Platform.current {
        case .watchOS: return false
        default: return true
        }
    }
    
    static var enableMetalRendering: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }
}
