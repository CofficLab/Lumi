import SwiftUI

struct AppTheme {
    struct Colors {
        static let primary = Color("AccentColor")
        static let background = Color(nsColor: .windowBackgroundColor) 
        
        static let gradientStart = Color(hex: "4facfe")
        static let gradientEnd = Color(hex: "00f2fe")
        
        static func gradient(for type: GradientType) -> LinearGradient {
            switch type {
            case .blue:
                return LinearGradient(colors: [Color(hex: "4facfe"), Color(hex: "00f2fe")], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .purple:
                return LinearGradient(colors: [Color(hex: "a18cd1"), Color(hex: "fbc2eb")], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .orange:
                return LinearGradient(colors: [Color(hex: "f6d365"), Color(hex: "fda085")], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .green:
                return LinearGradient(colors: [Color(hex: "84fab0"), Color(hex: "8fd3f4")], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .primary:
                 return LinearGradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }
    
    enum GradientType {
        case blue, purple, orange, green, primary
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// 创建自适应颜色（支持浅色/深色模式）
    /// - Parameters:
    ///   - light: 浅色模式下的 Hex 颜色字符串
    ///   - dark: 深色模式下的 Hex 颜色字符串
    init(light: String, dark: String) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                return NSColor(Color(hex: dark))
            } else {
                return NSColor(Color(hex: light))
            }
        })
    }
    
    /// 创建自适应颜色（支持浅色/深色模式）的静态方法
    static func adaptive(light: String, dark: String) -> Color {
        return Color(light: light, dark: dark)
    }
}
