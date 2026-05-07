import SwiftUI
import MagicKit

/// 组件库统一样式入口。
/// 业务层使用 AppUI，不直接依赖 DesignTokens。
enum AppUI {
    typealias Color = DesignTokens.Color
    typealias Typography = DesignTokens.Typography
    typealias Spacing = DesignTokens.Spacing
    typealias Radius = DesignTokens.Radius
    typealias Material = DesignTokens.Material
    typealias Duration = DesignTokens.Duration
    typealias Shadow = DesignTokens.Shadow
}

