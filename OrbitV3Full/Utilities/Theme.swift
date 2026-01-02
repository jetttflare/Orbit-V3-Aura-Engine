import SwiftUI

enum Theme {
    enum Colors {
        static let background = Color(red: 0.04, green: 0.055, blue: 0.15) // #0a0e27
        static let backgroundSecondary = Color(red: 0.1, green: 0.12, blue: 0.25) // #1a1e3f
        
        static let cyanPrimary = Color(red: 0, green: 0.85, blue: 1.0) // #00d9ff
        static let cyanGlow = Color(red: 0, green: 0.85, blue: 1.0).opacity(0.5)
        static let cyanDim = Color(red: 0, green: 0.85, blue: 1.0).opacity(0.3)
        
        static let purplePrimary = Color(red: 0.69, green: 0, blue: 1.0) // #b000ff
        static let purpleGlow = Color(red: 0.69, green: 0, blue: 1.0).opacity(0.5)
        
        static let success = Color(red: 0, green: 1.0, blue: 0.25) // #00ff41
        static let warning = Color(red: 1.0, green: 0.73, blue: 0) // #ffba00
        static let error = Color(red: 1.0, green: 0, blue: 0.43) // #ff006e
        
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.7)
        
        // Additional colors for panels and warfare theme
        static let crimsonText = Color(red: 0.86, green: 0.08, blue: 0.24) // #dc143c
        static let crimsonPrimary = Color(red: 0.86, green: 0.08, blue: 0.24) // #dc143c
        static let panelBackground = Color(red: 0.06, green: 0.08, blue: 0.18).opacity(0.85)
        static let cardBackground = Color(red: 0.08, green: 0.1, blue: 0.22)
        static let borderGlow = cyanPrimary.opacity(0.4)
    }
    
    enum Fonts {
        static func orbitron(_ size: CGFloat) -> Font {
            .custom("Orbitron", size: size)
        }
        
        static func rajdhani(_ size: CGFloat) -> Font {
            .custom("Rajdhani", size: size)
        }
        
        static func system(_ size: CGFloat) -> Font {
            .system(size: size, design: .monospaced)
        }
        
        // Additional font helpers
        static func codeMono(size: CGFloat) -> Font {
            .system(size: size, design: .monospaced)
        }
        
        static func techBold(size: CGFloat) -> Font {
            .custom("Orbitron", size: size).weight(.bold)
        }
        
        static var label: Font {
            .system(size: 11, design: .monospaced)
        }
        
        static var headline: Font {
            .custom("Orbitron", size: 16).weight(.bold)
        }
        
        static var title: Font {
            .custom("Orbitron", size: 20).weight(.bold)
        }
        
        static var caption: Font {
            .system(size: 10, design: .monospaced)
        }
        
        static var body: Font {
            .system(size: 14, design: .default)
        }
    }
    
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }
    
    enum Animation {
        static let fast = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let medium = SwiftUI.Animation.easeInOut(duration: 0.4)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.8)
        static let pulse = SwiftUI.Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)
    }
}
