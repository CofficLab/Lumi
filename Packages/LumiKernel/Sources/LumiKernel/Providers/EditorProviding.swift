import Foundation
import LumiUI
import SwiftUI

/// 编辑器服务能力协议
///
/// 定义 LumiCore 需要的编辑器功能，由具体编辑器插件实现。
/// 包括视图提供、文件操作和主题管理功能。
@MainActor
public protocol EditorProviding: AnyObject {
    // MARK: - 视图

    /// 创建编辑器视图。
    ///
    /// 由具体编辑器插件实现，内部自行跟踪当前文件（`currentFilePath`）。
    /// 消费方（如 EditorPanelPlugin）通过内核解析此服务并调用，无需关心实现细节。
    func makeEditorView() -> AnyView

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

    // MARK: - 插件注册

    /// 注册一个编辑器插件（语言、语法、主题等扩展）。
    ///
    /// 插件在 `EditorPlugin.registerExtensions(into:)` 中通过 host 提供的注册器写入编辑器运行时。
    /// - Parameter plugin: 实现 `EditorPlugin` 的编辑器插件实例。
    func registerEditorPlugin(_ plugin: any EditorPlugin)

    /// 用一组有效启用的编辑器插件替换当前插件扩展。
    ///
    /// 宿主应撤回不再启用的编辑器扩展，再按 `EditorPlugin.order` 回放传入插件。
    /// 语言插件的启用/禁用、插件列表重建都应走此入口，避免贡献残留。
    func replaceEditorPlugins(_ plugins: [any EditorPlugin])
}

// MARK: - 默认实现

public extension EditorProviding {
    /// `makeEditorView()` 的过渡兜底实现。
    ///
    /// 在具体编辑器插件实现该方法之前，返回占位视图，保证协议新增能力不破坏现有实现方。
    /// 具备视图能力的插件应覆盖此方法返回真正的编辑器视图。
    func makeEditorView() -> AnyView {
        AnyView(
            Text("Editor view not implemented")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
    }

    /// 默认实现保持向后兼容：没有撤回能力的旧实现只按顺序注册。
    /// 具备真实编辑器运行时的 Provider 应覆盖此方法并实现清空后回放。
    func replaceEditorPlugins(_ plugins: [any EditorPlugin]) {
        for plugin in plugins.sorted(by: editorPluginSort) {
            registerEditorPlugin(plugin)
        }
    }

    private func editorPluginSort(_ lhs: any EditorPlugin, _ rhs: any EditorPlugin) -> Bool {
        if lhs.order != rhs.order {
            return lhs.order < rhs.order
        }
        return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
    }
}
