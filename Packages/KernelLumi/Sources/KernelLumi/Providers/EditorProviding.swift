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
}
