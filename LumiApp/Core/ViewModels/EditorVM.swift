import Combine
import Foundation
import SwiftUI

/// 编辑器 ViewModel
///
/// 作为插件视图与内核 Editor 服务之间的桥梁，通过 SwiftUI 环境注入。
/// 在 `RootViewContainer` 中初始化，插件视图通过 `@EnvironmentObject` 访问。
///
/// ## 架构说明
///
/// - `state` — 主编辑器状态（活跃分栏的文件内容、光标、面板等）
/// - `sessionStore` — 会话管理（打开的文件标签页、导航历史）
/// - `workbench` — 工作台状态（分栏 group 树、活跃 group 追踪）
/// - `hostStore` — 分栏宿主（每个分栏独立的 EditorState 实例）
///
/// ## 使用方式
///
/// ```swift
/// @EnvironmentObject private var editorVM: EditorVM
///
/// // 访问编辑器状态
/// editorVM.state.cursorLine
/// editorVM.state.content
///
/// // 访问会话
/// editorVM.sessionStore.tabs
///
/// // 访问工作台
/// editorVM.workbench.activeGroup
/// ```
@MainActor
final class EditorVM: ObservableObject {

    /// 主编辑器状态
    let state: EditorState

    /// 会话管理
    let sessionStore: EditorSessionStore

    /// 工作台状态（分栏 group 树）
    let workbench: EditorWorkbenchState

    /// 分栏宿主（每个分栏独立的 EditorState）
    let hostStore: EditorGroupHostStore

    // MARK: - Initialization

    init(
        state: EditorState,
        sessionStore: EditorSessionStore,
        workbench: EditorWorkbenchState,
        hostStore: EditorGroupHostStore
    ) {
        self.state = state
        self.sessionStore = sessionStore
        self.workbench = workbench
        self.hostStore = hostStore
    }
}
