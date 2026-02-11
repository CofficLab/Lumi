import SwiftUI

// MARK: - 主题协议
///
/// 定义主题必须实现的接口，使主题系统更加灵活和可扩展。
/// 每个主题文件都应遵循此协议，实现自己的颜色、渐变和效果。
///
protocol ThemeProtocol {
    /// 主题唯一标识符
    var identifier: String { get }

    /// 主题显示名称
    var displayName: String { get }

    /// 主题简短名称（用于紧凑显示）
    var compactName: String { get }

    /// 主题描述
    var description: String { get }

    /// 主题图标（SF Symbols）
    var iconName: String { get }

    /// 主题主色调
    var iconColor: SwiftUI.Color { get }

    // MARK: - 颜色配置

    /// 主色调
    /// - Returns: (primary, secondary, tertiary)
    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color)

    /// 氛围色
    /// - Returns: (deep, medium, light)
    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color)

    /// 光晕色
    /// - Returns: (subtle, medium, intense)
    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color)

    // MARK: - 渐变配置

    /// 背景渐变
    func backgroundGradient() -> LinearGradient

    /// 光晕渐变
    func glowGradient() -> RadialGradient

    /// 边框渐变
    func borderGradient() -> LinearGradient
}

// MARK: - 主题协议默认实现
extension ThemeProtocol {
    /// 默认背景渐变实现
    func backgroundGradient() -> LinearGradient {
        let colors = atmosphereColors()
        return LinearGradient(
            colors: [
                colors.deep,
                colors.medium,
                colors.light,
                colors.medium,
                colors.deep
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// 默认光晕渐变实现
    func glowGradient() -> RadialGradient {
        let colors = glowColors()
        return RadialGradient(
            colors: [
                colors.intense,
                colors.medium,
                colors.subtle,
                SwiftUI.Color.clear
            ],
            center: .center,
            startRadius: 0,
            endRadius: 250
        )
    }

    /// 默认边框渐变实现
    func borderGradient() -> LinearGradient {
        return LinearGradient(
            colors: [
                SwiftUI.Color.clear,
                SwiftUI.Color.white.opacity(0.15),
                SwiftUI.Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
