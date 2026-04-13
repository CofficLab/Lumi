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

    /// 基于字符串（如人名）生成固定的自适应颜色
    ///
    /// 使用哈希算法将任意字符串映射到预定义的颜色列表中，
    /// 保证同一字符串总是生成相同颜色。适用于贡献者头像等场景。
    ///
    /// - Parameter source: 源字符串（如用户名）
    /// - Returns: 固定的颜色值
    static func adaptive(from source: String) -> Color {
        // 预定义的柔和色板（在浅色/深色模式下都能良好显示）
        let palette: [Color] = [
            Color(hex: "7C6FFF"),  // 主紫
            Color(hex: "FF6B6B"),  // 珊瑚红
            Color(hex: "4ECDC4"),  // 青绿
            Color(hex: "FFB347"),  // 暖橙
            Color(hex: "45B7D1"),  // 天蓝
            Color(hex: "96CEB4"),  // 薄荷绿
            Color(hex: "DDA0DD"),  // 梅紫
            Color(hex: "F7DC6F"),  // 暖黄
            Color(hex: "BB8FCE"),  // 薰衣草
            Color(hex: "85C1E9"),  // 淡蓝
            Color(hex: "F1948A"),  // 玫瑰
            Color(hex: "82E0AA"),  // 翠绿
        ]

        // 简单哈希：确保同一字符串始终映射到同一颜色
        var hash: UInt64 = 5381
        for byte in source.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        let index = Int(hash % UInt64(palette.count))
        return palette[max(0, index)]
    }
}
