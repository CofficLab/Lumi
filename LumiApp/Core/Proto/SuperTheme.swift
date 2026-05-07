import SwiftUI

// MARK: - 主题协议
///
/// 定义主题必须实现的接口，使主题系统更加灵活和可扩展。
/// 每个主题文件都应遵循此协议，实现自己的颜色、渐变和效果。
///
protocol SuperTheme {
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

    /// 是否为深色主题（影响工作区文本色等默认值）
    var isDarkTheme: Bool { get }

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

    // MARK: - 工作区颜色

    /// 编辑器工作区背景色（Tab 栏、工具栏、状态栏共享）
    func workspaceBackgroundColor() -> SwiftUI.Color

    /// 文件树侧边栏背景色
    func sidebarBackgroundColor() -> SwiftUI.Color

    /// 侧边栏选中行背景色
    func sidebarSelectionColor() -> SwiftUI.Color

    /// 侧边栏选中行文本色
    func sidebarSelectionTextColor() -> SwiftUI.Color

    /// 工作区主要文本色
    func workspaceTextColor() -> SwiftUI.Color

    /// 工作区次要文本色（图标、描述等）
    func workspaceSecondaryTextColor() -> SwiftUI.Color

    /// 工作区三级文本色（禁用、占位符等）
    func workspaceTertiaryTextColor() -> SwiftUI.Color

    // MARK: - 全局背景视图

    /// 创建全局背景视图
    /// - Parameter proxy: 几何代理，用于适配屏幕尺寸
    /// - Returns: 类型擦除的视图
    func makeGlobalBackground(proxy: GeometryProxy) -> AnyView
}

// MARK: - 主题协议默认实现
extension SuperTheme {
    // MARK: - 主题信息默认实现

    /// 默认为深色主题
    var isDarkTheme: Bool { true }

    // MARK: - 工作区颜色默认实现

    /// 默认工作区背景色：使用氛围色 medium
    func workspaceBackgroundColor() -> SwiftUI.Color {
        atmosphereColors().medium
    }

    /// 默认侧边栏背景色：使用氛围色 deep
    func sidebarBackgroundColor() -> SwiftUI.Color {
        atmosphereColors().deep
    }

    /// 默认侧边栏选中行背景色：主色调低透明度
    func sidebarSelectionColor() -> SwiftUI.Color {
        accentColors().primary.opacity(0.22)
    }

    /// 默认侧边栏选中行文本色
    func sidebarSelectionTextColor() -> SwiftUI.Color {
        isDarkTheme ? SwiftUI.Color.white : SwiftUI.Color.white
    }

    /// 默认工作区主要文本色
    func workspaceTextColor() -> SwiftUI.Color {
        isDarkTheme ? SwiftUI.Color.white : SwiftUI.Color(hex: "1C1C1E")
    }

    /// 默认工作区次要文本色（图标、描述等）
    func workspaceSecondaryTextColor() -> SwiftUI.Color {
        isDarkTheme ? SwiftUI.Color.white.opacity(0.6) : SwiftUI.Color(hex: "6B6B7B")
    }

    /// 默认工作区三级文本色（禁用、占位符等）
    func workspaceTertiaryTextColor() -> SwiftUI.Color {
        isDarkTheme ? SwiftUI.Color.white.opacity(0.4) : SwiftUI.Color(hex: "98989E")
    }

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

    /// 默认全局背景视图实现
    func makeGlobalBackground(proxy: GeometryProxy) -> AnyView {
        AnyView(
            ZStack {
                // 主光晕
                Circle()
                    .fill(glowGradient())
                    .frame(width: 600, height: 600)
                    .blur(radius: 120)
                    .offset(x: -200, y: -200)

                // 次光晕
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                glowColors().intense,
                                glowColors().medium,
                                SwiftUI.Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 250
                        )
                    )
                    .frame(width: 500, height: 500)
                    .blur(radius: 120)
                    .position(x: proxy.size.width, y: proxy.size.height)
            }
        )
    }
}
