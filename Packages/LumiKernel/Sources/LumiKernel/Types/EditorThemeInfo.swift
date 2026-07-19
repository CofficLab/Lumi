import Foundation

/// 编辑器主题元数据
///
/// 描述编辑器语法高亮主题的基本信息，不包含具体的调色板数据。
/// 用于主题列表展示和主题切换。
public struct EditorThemeInfo: Sendable, Equatable, Identifiable {
    /// 主题唯一标识符（如 "xcode-dark"、"monokai"）
    public let id: String

    /// 主题展示名称
    public let displayName: String

    /// 主题图标名称（SF Symbol，可选）
    public let iconName: String?

    /// 是否为深色主题
    public let isDark: Bool

    public init(id: String, displayName: String, iconName: String? = nil, isDark: Bool) {
        self.id = id
        self.displayName = displayName
        self.iconName = iconName
        self.isDark = isDark
    }
}