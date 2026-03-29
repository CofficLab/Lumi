import SwiftUI

/// 插件层可用的主题门面：屏蔽对 DesignTokens 的直接依赖。
enum AppTypography {
    static let caption1 = DesignTokens.Typography.caption1
    static let caption2 = DesignTokens.Typography.caption2
    static let callout = DesignTokens.Typography.callout
    static let body = DesignTokens.Typography.body
    static let bodyEmphasized = DesignTokens.Typography.bodyEmphasized
    static let code = DesignTokens.Typography.code
}

enum AppColor {
    static let textPrimary = DesignTokens.Color.semantic.textPrimary
    static let textSecondary = DesignTokens.Color.semantic.textSecondary
    static let textTertiary = DesignTokens.Color.semantic.textTertiary
    static let primary = DesignTokens.Color.semantic.primary
    static let info = DesignTokens.Color.semantic.info
    static let warning = DesignTokens.Color.semantic.warning
    static let error = DesignTokens.Color.semantic.error
    static let success = DesignTokens.Color.semantic.success
}

enum AppRadius {
    static let sm = DesignTokens.Radius.sm
    static let md = DesignTokens.Radius.md
}

enum AppMaterial {
    static let glass = DesignTokens.Material.glass
}
