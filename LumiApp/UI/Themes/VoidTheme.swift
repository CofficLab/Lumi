import SwiftUI

// MARK: - 虚空深黑主题
///
/// 纯粹的虚空黑，深邃而神秘。
/// 特点：黑靛色调，极简主义
///
struct VoidTheme: ThemeProtocol {
    // MARK: - 主题信息

    let identifier = "void"
    let displayName = "虚空深黑"
    let compactName = "虚空"
    let description = "纯粹的虚空黑，深邃而神秘"
    let iconName = "circle.fill"

    var iconColor: SwiftUI.Color {
        SwiftUI.Color(hex: "6366F1")
    }

    // MARK: - 颜色配置

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color(hex: "6366F1"),  // 虚空靛
            secondary: SwiftUI.Color(hex: "8B5CF6"), // 虚空紫
            tertiary: SwiftUI.Color(hex: "EC4899")  // 虚空粉
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color(hex: "020205"),     // 虚空之深
            medium: SwiftUI.Color(hex: "080810"),   // 虚空中层
            light: SwiftUI.Color(hex: "101018")     // 虚空浅层
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color(hex: "6366F1").opacity(0.3),
            medium: SwiftUI.Color(hex: "8B5CF6").opacity(0.5),
            intense: SwiftUI.Color(hex: "EC4899").opacity(0.7)
        )
    }
}
