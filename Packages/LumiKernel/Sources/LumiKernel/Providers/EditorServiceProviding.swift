import Foundation
import LumiUI

/// 编辑器服务能力协议
///
/// 定义 LumiCore 需要的编辑器功能，由具体编辑器插件实现。
/// 包括文件操作和主题管理功能。
@MainActor
public protocol EditorServiceProviding: AnyObject {
    // MARK: - 文件操作

    /// 打开文件
    func openFile(at path: String) async throws

    /// 关闭文件
    func closeFile(at path: String) async

    /// 当前文件路径
    var currentFilePath: String? { get }

    // MARK: - 主题管理

    /// 当前编辑器主题 ID
    var currentThemeId: String { get }

    /// 设置当前编辑器主题
    /// - Parameter themeId: 主题唯一标识符
    func setCurrentTheme(_ themeId: String) throws

    /// 所有已注册的编辑器主题
    var allEditorThemes: [EditorThemeInfo] { get }

    /// 注册编辑器主题
    /// - Parameter theme: 主题元数据
    func registerEditorTheme(_ theme: EditorThemeInfo)

    /// 注销编辑器主题
    /// - Parameter themeId: 主题唯一标识符
    func unregisterEditorTheme(themeId: String)
}

// MARK: - Raw EditorService Access

/// 扩展用于获取底层 EditorService 实例
/// 实现者可通过此方法返回原始的 EditorService 实例
@MainActor
public extension EditorServiceProviding {
    /// 返回底层 EditorService 实例（如果有）
    /// 默认返回 nil
    var rawEditorService: AnyObject? {
        nil
    }
}
