import Combine
import Foundation
import AppKit
import CodeEditSourceEditor
import CodeEditLanguages
import LanguageServerProtocol

// MARK: - EditorService
//
// 编辑器子系统的 **唯一对外门面（Facade）**。
//
// ## 设计原则
//
// EditorService 是编辑器模块的唯一对外入口。
// 所有内部类型（EditorState、EditorSession、EditorWorkbenchState、
// EditorGroupHostStore、EditorSessionStore 等）均通过此服务暴露，
// 外部消费者不直接引用内部实现。
//
// ## 内部组件（不对外暴露）
//
// | 组件                  | 职责                                |
// |-----------------------|-------------------------------------|
// | `EditorState`         | 当前活跃编辑器的全部状态与 LSP 交互  |
// | `sessionStore`        | 会话/标签页管理、导航历史            |
// | `workbench`           | 分栏 Group 树管理                   |
// | `hostStore`           | 每个分栏独立的 EditorState 实例      |
//
// ## 使用方式
//
// ```swift
// @EnvironmentObject private var editor: EditorService
//
// // 打开文件
// editor.openFile(at: url)
//
// // 访问当前文件
// editor.currentFileURL
//
// // 执行命令
// editor.performCommand(id: "builtin.find")
//
// // 分栏
// editor.splitRight()
// ```
@MainActor
public final class EditorService: ObservableObject {

    // MARK: - Internal Components（不对外暴露）

    /// 主编辑器状态（活跃分栏的文件内容、光标、面板等）
    let state: EditorState

    /// 会话管理（打开的文件标签页、导航历史）
    let sessionStore: EditorSessionStore

    /// 工作台状态（分栏 group 树）
    let workbench: EditorWorkbenchState

    /// 分栏宿主（每个分栏独立的 EditorState 实例）
    let hostStore: EditorGroupHostStore

    // MARK: - Initialization

    /// 编辑器扩展注册中心（由 RootViewContainer 创建并注入）
    let editorExtensionRegistry: EditorExtensionRegistry

    init(
        editorExtensionRegistry: EditorExtensionRegistry,
        state: EditorState,
        sessionStore: EditorSessionStore,
        workbench: EditorWorkbenchState,
        hostStore: EditorGroupHostStore
    ) {
        self.editorExtensionRegistry = editorExtensionRegistry
        self.state = state
        self.sessionStore = sessionStore
        self.workbench = workbench
        self.hostStore = hostStore
        hostStore.configureRegistry(editorExtensionRegistry)
    }

    /// 便捷构造：使用默认实例创建完整编辑器服务
    convenience init(editorExtensionRegistry: EditorExtensionRegistry) {
        self.init(
            editorExtensionRegistry: editorExtensionRegistry,
            state: EditorState(editorExtensions: editorExtensionRegistry),
            sessionStore: EditorSessionStore(),
            workbench: EditorWorkbenchState(),
            hostStore: EditorGroupHostStore()
        )
    }

    // ========================================================================
    // MARK: - 文件操作（File Operations）
    // ========================================================================

    /// 当前打开的文件 URL
    var currentFileURL: URL? { state.currentFileURL }

    /// 当前文件名
    var fileName: String { state.fileName }

    /// 当前文件扩展名
    var fileExtension: String { state.fileExtension }

    /// 当前文件内容（NSTextStorage）
    var content: NSTextStorage? { state.content }

    /// 当前文件相对于项目根目录的路径
    var relativeFilePath: String { state.relativeFilePath }

    /// 当前文件是否可编辑
    var isEditable: Bool { state.isEditable }

    /// 当前文件是否为截断预览
    var isTruncated: Bool { state.isTruncated }

    /// 当前文件是否为二进制文件
    var isBinaryFile: Bool { state.isBinaryFile }

    /// 当前文件是否为 Markdown 格式
    var isMarkdownFile: Bool { state.isMarkdownFile }

    /// 是否有未保存的变更
    var hasUnsavedChanges: Bool { state.hasUnsavedChanges }

    /// 保存当前文件
    func saveNow() {
        state.saveNow()
    }

    // ========================================================================
    // MARK: - 会话管理（Session Management）
    // ========================================================================

    /// 打开或激活文件会话
    @discardableResult
    func openFile(at url: URL?) -> EditorSession? {
        sessionStore.openOrActivate(fileURL: url)
    }

    /// 当前活跃会话
    var activeSession: EditorSession? { sessionStore.activeSession }

    /// 当前活跃会话 ID
    var activeSessionID: EditorSession.ID? { sessionStore.activeSessionID }

    /// 所有打开的会话
    var sessions: [EditorSession] { sessionStore.sessions }

    /// 所有标签页
    var tabs: [EditorTab] { sessionStore.tabs }

    /// 关闭指定会话
    @discardableResult
    func closeSession(id: EditorSession.ID) -> EditorSession? {
        sessionStore.close(sessionID: id)
    }

    /// 关闭其他会话（保留指定会话）
    @discardableResult
    func closeOtherSessions(keeping id: EditorSession.ID) -> EditorSession? {
        sessionStore.closeOthers(keeping: id)
    }

    /// 关闭所有会话
    func closeAllSessions() {
        sessionStore.closeAll()
    }

    /// 激活指定会话
    @discardableResult
    func activateSession(id: EditorSession.ID) -> EditorSession? {
        sessionStore.activate(sessionID: id)
    }

    /// 切换固定状态
    func togglePinned(sessionID: EditorSession.ID) {
        sessionStore.togglePinned(sessionID: sessionID)
    }

    /// 重新排序标签页
    @discardableResult
    func reorderSession(sessionID: EditorSession.ID, before targetID: EditorSession.ID?) -> Bool {
        sessionStore.reorderSession(sessionID: sessionID, before: targetID)
    }

    /// 获取指定会话
    func session(for sessionID: EditorSession.ID) -> EditorSession? {
        sessionStore.session(for: sessionID)
    }

    /// 获取指定会话的最近激活排名
    func recentActivationRank(for sessionID: EditorSession.ID) -> Int? {
        sessionStore.recentActivationRank(for: sessionID)
    }

    // ========================================================================
    // MARK: - 导航（Navigation）
    // ========================================================================

    /// 是否可以后退
    var canNavigateBack: Bool { sessionStore.canNavigateBack }

    /// 是否可以前进
    var canNavigateForward: Bool { sessionStore.canNavigateForward }

    /// 后退导航
    @discardableResult
    func goBack() -> EditorSession? {
        sessionStore.goBack()
    }

    /// 前进导航
    @discardableResult
    func goForward() -> EditorSession? {
        sessionStore.goForward()
    }

    // ========================================================================
    // MARK: - 分栏管理（Workbench / Split）
    // ========================================================================

    /// 根 Group
    var rootGroup: EditorGroup { workbench.rootGroup }

    /// 当前活跃的 Group ID
    var activeGroupID: EditorGroup.ID { workbench.activeGroupID }

    /// 当前活跃的 Group
    var activeGroup: EditorGroup? { workbench.activeGroup }

    /// 所有叶子 Group（包含实际编辑器内容的 group）
    var leafGroups: [EditorGroup] { workbench.leafGroups }

    /// 是否为多分栏模式
    var isSplitMode: Bool { !workbench.rootGroup.isLeaf }

    /// 水平分割编辑器（左右分栏）
    func splitRight() {
        workbench.splitActiveGroup(.horizontal)
    }

    /// 垂直分割编辑器（上下分栏）
    func splitDown() {
        workbench.splitActiveGroup(.vertical)
    }

    /// 取消分割
    func unsplit() {
        workbench.unsplitActiveGroup()
    }

    /// 聚焦到下一个分栏
    @discardableResult
    func focusNextGroup() -> EditorGroup? {
        workbench.focusNextGroup()
    }

    /// 聚焦到上一个分栏
    @discardableResult
    func focusPreviousGroup() -> EditorGroup? {
        workbench.focusPreviousGroup()
    }

    /// 将活跃会话移动到下一个分栏
    @discardableResult
    func moveActiveSessionToNextGroup() -> Bool {
        workbench.moveActiveSessionToNextGroup()
    }

    /// 将活跃会话移动到上一个分栏
    @discardableResult
    func moveActiveSessionToPreviousGroup() -> Bool {
        workbench.moveActiveSessionToPreviousGroup()
    }

    /// 激活指定 Group
    func activateGroup(_ groupID: EditorGroup.ID) {
        workbench.activateGroup(groupID)
    }

    // ========================================================================
    // MARK: - 光标与编辑器状态（Cursor & Editor State）
    // ========================================================================

    /// 当前行号
    var cursorLine: Int { state.cursorLine }

    /// 当前列号
    var cursorColumn: Int { state.cursorColumn }

    /// 总行数
    var totalLines: Int { state.totalLines }

    /// 检测到的语言
    var detectedLanguage: CodeLanguage? { state.detectedLanguage }

    /// 是否可以撤销
    var canUndo: Bool { state.canUndo }

    /// 是否可以重做
    var canRedo: Bool { state.canRedo }

    /// 多光标状态
    var multiCursorState: MultiCursorState { state.multiCursorState }

    // ========================================================================
    // MARK: - 查找与替换（Find & Replace）
    // ========================================================================

    /// 查找匹配结果
    var findMatches: [EditorFindMatch] { state.findMatches }

    /// 当前查找匹配项
    var currentFindMatch: EditorFindMatch? { state.currentFindMatch }

    // ========================================================================
    // MARK: - 诊断与问题（Diagnostics & Problems）
    // ========================================================================

    /// 当前文件的诊断列表
    var problemDiagnostics: [Diagnostic] { state.problemDiagnostics }

    /// 是否展示 Problems 面板
    var isProblemsPanelPresented: Bool { state.isProblemsPanelPresented }

    /// References 结果列表
    var referenceResults: [ReferenceResult] { state.referenceResults }

    /// 是否展示 References 面板
    var isReferencePanelPresented: Bool { state.isReferencePanelPresented }

    // ========================================================================
    // MARK: - 主题与配置（Theme & Configuration）
    // ========================================================================

    /// 当前主题
    var currentTheme: EditorTheme? { state.currentTheme }

    /// 当前主题 ID
    var currentThemeId: String { state.currentThemeId }

    /// 字体大小
    var fontSize: Double { state.fontSize }

    /// Tab 宽度
    var tabWidth: Int { state.tabWidth }

    /// 是否使用空格替代 Tab
    var useSpaces: Bool { state.useSpaces }

    /// 是否自动换行
    var wrapLines: Bool { state.wrapLines }

    /// 是否显示 Minimap
    var showMinimap: Bool { state.showMinimap }

    /// 是否显示行号
    var showGutter: Bool { state.showGutter }

    /// 是否显示代码折叠
    var showFoldingRibbon: Bool { state.showFoldingRibbon }

    // ========================================================================
    // MARK: - 命令执行（Command Execution）
    // ========================================================================

    /// 执行编辑器命令
    func performCommand(id: String) {
        state.performEditorCommand(id: id)
    }

    /// 获取命令建议列表
    func commandSuggestions() -> [EditorCommandSuggestion] {
        state.editorCommandSuggestions()
    }

    /// 获取命令分组列表
    func commandSections(matching query: String = "") -> [EditorCommandSection] {
        state.editorCommandSections(matching: query)
    }

    // ========================================================================
    // MARK: - 面板操作（Panel Operations）
    // ========================================================================

    /// 切换 Open Editors 面板
    func toggleOpenEditorsPanel() {
        state.performPanelCommand(.toggleOpenEditors)
    }

    /// 切换 Outline 面板
    func toggleOutlinePanel() {
        state.performPanelCommand(.toggleOutline)
    }

    /// 切换 Problems 面板
    func toggleProblemsPanel() {
        state.performPanelCommand(.toggleProblems)
    }

    // ========================================================================
    // MARK: - 项目上下文（Project Context）
    // ========================================================================

    /// 当前项目根路径
    var projectRootPath: String? {
        get { state.projectRootPath }
        set { state.projectRootPath = newValue }
    }

    /// 当前项目上下文快照
    var projectContextSnapshot: EditorProjectContextSnapshot? {
        state.projectContextSnapshot
    }

    /// 刷新项目上下文
    func refreshProjectContext() {
        state.refreshProjectContextSnapshot()
    }

    // ========================================================================
    // MARK: - 编辑器扩展（Extension Access）
    // ========================================================================

    /// 已安装的编辑器插件信息
    var editorFeaturePlugins: [EditorState.EditorPluginInfo] {
        state.editorFeaturePlugins
    }

    /// 文档符号提供者
    var documentSymbolProvider: any SuperEditorDocumentSymbolProvider {
        state.documentSymbolProvider
    }

    /// 代码动作提供者
    var codeActionProvider: any SuperEditorCodeActionProvider {
        state.codeActionProvider
    }

    // ========================================================================
    // MARK: - LSP 能力（LSP Capabilities）
    // ========================================================================

    /// LSP 客户端
    var lspClient: any SuperEditorLSPClient {
        state.lspClient
    }

    /// 当前项目上下文状态
    var projectContextStatus: EditorProjectContextStatus {
        state.currentProjectContextStatus
    }

    /// 当前项目上下文状态描述
    var projectContextStatusDescription: String {
        state.currentProjectContextStatusDescription
    }

    // ========================================================================
    // MARK: - 鼠标悬停（Mouse Hover）
    // ========================================================================

    /// 鼠标悬停内容
    var mouseHoverContent: String? { state.mouseHoverContent }

    /// 设置鼠标悬停状态
    func setMouseHover(content: String, symbolRect: CGRect) {
        state.setMouseHover(content: content, symbolRect: symbolRect)
    }

    /// 清除鼠标悬停状态
    func clearMouseHover() {
        state.clearMouseHover()
    }

    // ========================================================================
    // MARK: - 保存状态（Save State）
    // ========================================================================

    /// 保存状态
    var saveState: EditorSaveState { state.saveState }

    /// 是否有外部文件冲突
    var hasExternalFileConflict: Bool { state.hasExternalFileConflict }

    // ========================================================================
    // MARK: - 大文件模式（Large File Mode）
    // ========================================================================

    /// 大文件模式
    var largeFileMode: LargeFileMode { state.largeFileMode }

    /// 加载完整文件
    func loadFullFile() {
        state.loadFullFileFromDisk()
    }

    /// 是否可以加载完整文件
    var canLoadFullFile: Bool { state.canLoadFullFile }

    // ========================================================================
    // MARK: - 显示状态（Display State）
    // ========================================================================

    /// 是否为 Markdown 预览模式
    var isMarkdownPreviewMode: Bool { state.isMarkdownPreviewMode }

    /// 切换 Markdown 预览模式
    func toggleMarkdownPreview() {
        state.isMarkdownPreviewMode.toggle()
    }

    /// 是否展示 Code Action 面板
    var isCodeActionPanelPresented: Bool { state.isCodeActionPanelPresented }

    /// 切换 Code Action 面板
    func toggleCodeActionPanel() {
        state.toggleCodeActionPanel()
    }

    // ========================================================================
    // MARK: - Hover / Signature / Inline Rename（Overlay 状态）
    // ========================================================================

    /// Hover 文本
    var hoverText: String? { state.hoverText }

    /// 当前 Peek 表示
    var currentPeekPresentation: EditorPeekPresentation? { state.currentPeekPresentation }

    /// 当前内联重命名状态
    var currentInlineRenameState: EditorInlineRenameState? { state.currentInlineRenameState }

    // ========================================================================
    // MARK: - Workspace Search / Call Hierarchy
    // ========================================================================

    /// 是否展示工作区符号搜索面板
    var isWorkspaceSymbolSearchPresented: Bool { state.isWorkspaceSymbolSearchPresented }

    /// 是否展示调用层级面板
    var isCallHierarchyPresented: Bool { state.isCallHierarchyPresented }

    // ========================================================================
    // MARK: - Session Snapshot Sync（内部协调）
    // ========================================================================

    /// 从快照同步活跃会话到工作台
    func syncActiveSession(from snapshot: EditorSession) {
        sessionStore.syncActiveSession(from: snapshot)
        workbench.syncActiveSession(from: snapshot)
    }

    // ========================================================================
    // MARK: - 分栏宿主管理（Host Store）
    // ========================================================================

    /// 获取指定 Group 的 EditorState（分栏场景下使用）
    func hostedState(for groupID: EditorGroup.ID) -> EditorState {
        hostStore.state(for: groupID)
    }

    /// 设置主 EditorState 引用
    func setPrimaryState(_ state: EditorState) {
        hostStore.setPrimaryState(state)
    }

    /// 保留指定 Group 的 EditorState，清理其余
    func retainHostStates(for groupIDs: Set<EditorGroup.ID>) {
        hostStore.retainOnly(groupIDs)
    }

    /// 所有已托管的 EditorState
    var allHostedStates: [EditorState] {
        hostStore.allStates
    }

    // ========================================================================
    // MARK: - 通知桥接（Notification Bridge）
    // ========================================================================

    /// 活跃会话变化回调（由 EditorPanelView 注册）
    var onActiveSessionChanged: ((EditorSession) -> Void)? {
        get { state.onActiveSessionChanged }
        set { state.onActiveSessionChanged = newValue }
    }
}
