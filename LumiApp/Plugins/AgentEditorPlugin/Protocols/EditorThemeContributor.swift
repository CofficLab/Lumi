import Foundation
import CodeEditSourceEditor

// MARK: - Theme Contributor

/// 编辑器主题扩展点。
///
/// 每个主题插件实现此协议，提供主题的元数据和 `EditorTheme` 实例。
/// 通过 `EditorExtensionRegistry.registerThemeContributor(_:)` 注册后，
/// 编辑器工具栏的主题选择器会自动展示该主题。
@MainActor
protocol EditorThemeContributor: AnyObject {
    /// 主题唯一标识（如 "xcode-dark"、"monokai"）
    var id: String { get }
    /// 主题展示名称
    var displayName: String { get }
    /// 主题图标名称（SF Symbol，可选）
    var icon: String? { get }
    /// 是否为深色主题
    var isDark: Bool { get }
    /// 生成主题实例
    func createTheme() -> EditorTheme
}
