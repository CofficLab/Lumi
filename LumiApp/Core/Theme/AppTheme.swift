import SwiftUI
import LumiUI

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
