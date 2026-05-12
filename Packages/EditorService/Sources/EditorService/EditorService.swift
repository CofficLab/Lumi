import Combine
import Foundation
import AppKit
import CodeEditSourceEditor
import CodeEditTextView
import CodeEditLanguages
import LanguageServerProtocol

// MARK: - EditorService
//
// 编辑器子系统的 **唯一对外门面（Facade）**。
//
// ## 设计原则
//
// EditorService 是编辑器模块的唯一对外入口。
// 所有内部类型（EditorState、EditorSessionStore 等）均通过此服务暴露，
// 外部消费者不直接引用内部实现。
//
// ## 内部组件（不对外暴露）
//
// | 组件                  | 职责                                |
// |-----------------------|-------------------------------------|
// | `EditorState`         | 当前活跃编辑器的全部状态与 LSP 交互  |
// | `sessionStore`        | 会话/标签页管理、导航历史            |
//
// ## 使用方式
//
// ```swift
// @EnvironmentObject private var editor: EditorService
//
// // 打开文件
// editor.open(at: url)
//
// // 访问当前文件
// editor.currentFileURL
//
// // 执行命令
// editor.performCommand(id: "builtin.find")
// ```
@MainActor
public final class EditorService: ObservableObject {

    // MARK: - Internal Components（不对外暴露）

    /// 主编辑器状态（文件内容、光标、面板等）
    public let state: EditorState

    /// 会话管理（打开的文件标签页、导航历史）
    public let sessionStore: EditorSessionStore

    /// 将 `sessionStore` 的 `objectWillChange` 暴露给宿主（例如 `EditorVM`），而不放宽 `sessionStore` 的访问级别。
    public var sessionObjectWillChange: AnyPublisher<Void, Never> {
        sessionStore.objectWillChange.map { _ in () }.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    /// 编辑器扩展注册中心（由 RootViewContainer 创建并注入）
    let editorExtensionRegistry: EditorExtensionRegistry

    private var activeSessionChangedObserver: ((EditorSession) -> Void)?

    init(
        editorExtensionRegistry: EditorExtensionRegistry,
        state: EditorState,
        sessionStore: EditorSessionStore
    ) {
        self.editorExtensionRegistry = editorExtensionRegistry
        self.state = state
        self.sessionStore = sessionStore
        installActiveSessionSyncBridge()
    }

    /// 便捷构造：使用默认实例创建完整编辑器服务
    public convenience init(editorExtensionRegistry: EditorExtensionRegistry) {
        self.init(
            editorExtensionRegistry: editorExtensionRegistry,
            state: EditorState(editorExtensions: editorExtensionRegistry),
            sessionStore: EditorSessionStore()
        )
    }

    // ========================================================================
    // MARK: - 文件操作（File Operations）
    // ========================================================================

    /// 当前打开的文件 URL
    public var currentFileURL: URL? { state.currentFileURL }

    /// 当前文件是否仍在加载
    public var isFileLoadInProgress: Bool { state.isFileLoadInProgress }

    /// 最近一次文件加载错误
    public var fileLoadErrorMessage: String? { state.fileLoadErrorMessage }

    /// 当前文件名
    public var fileName: String { state.fileName }

    /// 当前文件扩展名
    public var fileExtension: String { state.fileExtension }

    /// 当前文件内容（NSTextStorage）
    public var content: NSTextStorage? { state.content }

    /// 当前文档文本变更版本号。
    public var contentRevision: UInt64 { state.contentRevision }

    /// 当前文件相对于项目根目录的路径
    public var relativeFilePath: String { state.relativeFilePath }

    /// 当前文件是否可编辑
    public var isEditable: Bool { state.isEditable }

    /// 当前文件是否为截断预览
    public var isTruncated: Bool { state.isTruncated }

    /// 当前文件是否为二进制文件
    public var isBinaryFile: Bool { state.isBinaryFile }

    /// 当前文件是否为 Markdown 格式
    public var isMarkdownFile: Bool { state.isMarkdownFile }

    /// 是否有未保存的变更
    public var hasUnsavedChanges: Bool { state.hasUnsavedChanges }

    /// 保存当前文件
    public func saveNow() {
        state.saveNow()
    }

    /// 当前文件是否可预览（代码编辑器可渲染）
    public var canPreview: Bool { state.canPreview }

    /// 加载文件内容到编辑器（底层操作，优先使用 open(at:)）
    public func loadFile(from url: URL?) {
        state.loadFile(from: url)
    }

    /// 恢复会话交互状态（光标、滚动位置、折叠等，底层操作）
    public func applySessionRestore(_ session: EditorSession) {
        state.applySessionRestore(session)
    }

    // ========================================================================
    // MARK: - 会话管理（Session Management）
    // ========================================================================

    /// 打开或激活文件会话（仅创建 session，不加载内容）
    @discardableResult
    public func openFile(at url: URL?) -> EditorSession? {
        sessionStore.openOrActivate(fileURL: url)
    }

    /// 打开文件
    ///
    /// 编辑器打开文件的唯一对外入口。完整的「打开文件」流程：
    /// 创建/激活 Session → 加载文件内容 → 恢复交互状态（光标、滚动位置等）。
    ///
    /// - Parameter url: 要打开的文件 URL，传 nil 无效。
    public func open(at url: URL?) {
        guard let url else { return }

        guard let session = sessionStore.openOrActivate(fileURL: url) else { return }

        let canRestoreImmediately =
            state.currentFileURL == url &&
            state.content != nil &&
            state.focusedTextView != nil

        if canRestoreImmediately {
            state.applySessionRestore(session)
            return
        }

        if state.currentFileURL != url {
            state.loadFile(from: url)
        }
    }

    /// 激活已存在的会话并渲染到编辑器
    ///
    /// 用于 Tab 切换场景：激活已有 Session → 加载文件内容 → 恢复交互状态。
    /// 如果 Session 不存在则忽略。
    ///
    /// - Parameter id: 要激活的 Session ID。
    public func activateAndRestoreSession(id: EditorSession.ID) {
        guard let session = sessionStore.activate(sessionID: id) else { return }

        let fileURL = session.fileURL

        let canRestoreImmediately =
            state.currentFileURL == fileURL &&
            state.content != nil &&
            state.focusedTextView != nil

        if canRestoreImmediately {
            state.applySessionRestore(session)
            return
        }

        if state.currentFileURL != fileURL {
            state.loadFile(from: fileURL)
        }
    }

    /// 当前活跃会话
    public var activeSession: EditorSession? { sessionStore.activeSession }

    /// 当前活跃会话 ID
    public var activeSessionID: EditorSession.ID? { sessionStore.activeSessionID }

    /// 所有打开的会话
    var sessions: [EditorSession] { sessionStore.sessions }

    /// 所有标签页
    public var tabs: [EditorTab] { sessionStore.tabs }

    /// 关闭指定会话
    @discardableResult
    public func closeSession(id: EditorSession.ID) -> EditorSession? {
        sessionStore.close(sessionID: id)
    }

    /// 关闭其他会话（保留指定会话）
    @discardableResult
    public func closeOtherSessions(keeping id: EditorSession.ID) -> EditorSession? {
        sessionStore.closeOthers(keeping: id)
    }

    /// 关闭所有会话
    public func closeAllSessions() {
        sessionStore.closeAll()
    }

    /// 激活指定会话
    @discardableResult
    public func activateSession(id: EditorSession.ID) -> EditorSession? {
        sessionStore.activate(sessionID: id)
    }

    /// 切换固定状态
    public func togglePinned(sessionID: EditorSession.ID) {
        sessionStore.togglePinned(sessionID: sessionID)
    }

    /// 重新排序标签页
    @discardableResult
    public func reorderSession(sessionID: EditorSession.ID, before targetID: EditorSession.ID?) -> Bool {
        sessionStore.reorderSession(sessionID: sessionID, before: targetID)
    }

    /// 获取指定会话
    public func session(for sessionID: EditorSession.ID) -> EditorSession? {
        sessionStore.session(for: sessionID)
    }

    /// 获取指定会话的最近激活排名
    public func recentActivationRank(for sessionID: EditorSession.ID) -> Int? {
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
    public func goBack() -> EditorSession? {
        sessionStore.goBack()
    }

    /// 前进导航
    @discardableResult
    public func goForward() -> EditorSession? {
        sessionStore.goForward()
    }

    /// 执行导航请求（跳转定义、跳转引用等）
    public func performNavigation(_ request: EditorNavigationRequest) {
        state.performNavigation(request)
    }

    /// 执行打开项命令（问题跳转、符号跳转、调用层级跳转等）
    public func performOpenItem(_ command: EditorOpenItemCommand) {
        state.performOpenItem(command)
    }

    // ========================================================================
    // MARK: - 光标与编辑器状态（Cursor & Editor State）
    // ========================================================================

    /// 当前行号
    public var cursorLine: Int { state.cursorLine }

    /// 当前列号
    public var cursorColumn: Int { state.cursorColumn }

    /// 总行数
    var totalLines: Int { state.totalLines }

    /// 检测到的语言
    public var detectedLanguage: CodeLanguage? { state.detectedLanguage }

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
    public var problemDiagnostics: [Diagnostic] { state.problemDiagnostics }

    /// 当前文件的语义问题列表
    public var semanticProblems: [EditorSemanticProblem] { state.semanticProblems }

    /// 是否展示 Problems 面板
    var isProblemsPanelPresented: Bool { state.isProblemsPanelPresented }

    /// References 结果列表
    var referenceResults: [ReferenceResult] { state.referenceResults }

    /// 是否展示 References 靖板
    var isReferencePanelPresented: Bool { state.isReferencePanelPresented }

    // ========================================================================
    // MARK: - 主题与配置（Theme & Configuration）
    // ========================================================================

    /// 当前主题
    public var currentTheme: EditorTheme? { state.currentTheme }

    /// 当前主题 ID
    public var currentThemeId: String { state.currentThemeId }

    /// 字体大小
    public var fontSize: Double { state.fontSize }

    /// Tab 宽度
    public var tabWidth: Int { state.tabWidth }

    /// 是否使用空格替代 Tab
    public var useSpaces: Bool { state.useSpaces }

    /// 是否自动换行
    public var wrapLines: Bool { state.wrapLines }

    /// 是否显示 Minimap
    public var showMinimap: Bool { state.showMinimap }

    /// 是否显示行号
    public var showGutter: Bool { state.showGutter }

    /// 是否显示代码折叠
    public var showFoldingRibbon: Bool { state.showFoldingRibbon }

    // ========================================================================
    // MARK: - 命令执行（Command Execution）
    // ========================================================================

    /// 执行编辑器命令
    public func performCommand(id: String) {
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

    /// 执行面板命令（通用）
    public func performPanelCommand(_ command: EditorPanelCommand) {
        state.performPanelCommand(command)
    }

    /// 展示底部面板
    public func presentBottomPanel(_ panel: EditorBottomPanelKind?) {
        state.presentBottomPanel(panel)
    }

    // ========================================================================
    // MARK: - 项目上下文（Project Context）
    // ========================================================================

    /// 当前项目根路径
    public var projectRootPath: String? {
        get { state.projectRootPath }
        set { state.projectRootPath = newValue }
    }

    /// 当前项目上下文快照
    public var projectContextSnapshot: EditorProjectContextSnapshot? {
        state.projectContextSnapshot
    }

    /// 刷新项目上下文
    public func refreshProjectContext() {
        state.refreshProjectContextSnapshot()
    }

    /// 刷新指定项目的上下文能力。
    public func refreshProjectContext(for projectPath: String?) async {
        let trimmedPath = projectPath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedPath.isEmpty else {
            state.projectRootPath = nil
            state.refreshProjectContextSnapshot()
            return
        }

        state.projectRootPath = trimmedPath
        await state.projectContextCapability?.projectOpened(at: trimmedPath)
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
    public var documentSymbolProvider: any SuperEditorDocumentSymbolProvider {
        state.documentSymbolProvider
    }

    /// 代码动作提供者
    public var codeActionProvider: any SuperEditorCodeActionProvider {
        state.codeActionProvider
    }

    // ========================================================================
    // MARK: - LSP 能力（LSP Capabilities）
    // ========================================================================

    /// LSP 客户端
    public var lspClient: any SuperEditorLSPClient {
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
    func setMouseHover(content: String, symbolRect: CGRect, hoverRange: LSPRange? = nil) {
        state.setMouseHover(content: content, symbolRect: symbolRect, hoverRange: hoverRange)
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
    public var largeFileMode: LargeFileMode { state.largeFileMode }

    /// 加载完整文件
    public func loadFullFile() {
        state.loadFullFileFromDisk()
    }

    /// 是否可以加载完整文件
    public var canLoadFullFile: Bool { state.canLoadFullFile }

    // ========================================================================
    // MARK: - 显示状态（Display State）
    // ========================================================================

    /// 是否为 Markdown 预览模式
    public var isMarkdownPreviewMode: Bool { state.isMarkdownPreviewMode }

    /// 切换 Markdown 预览模式
    func toggleMarkdownPreview() {
        state.isMarkdownPreviewMode.toggle()
    }

    /// 是否展示 Code Action 面板
    public var isCodeActionPanelPresented: Bool { state.isCodeActionPanelPresented }

    /// 切换 Code Action 面板
    public func toggleCodeActionPanel() {
        state.toggleCodeActionPanel()
    }

    // ========================================================================
    // MARK: - Hover / Signature / Inline Rename（Overlay 状态）
    // ========================================================================

    /// Hover 文本
    var hoverText: String? { state.hoverText }

    /// 当前 Peek 表示
    public var currentPeekPresentation: EditorPeekPresentation? { state.currentPeekPresentation }

    /// 当前内联重命名状态
    public var currentInlineRenameState: EditorInlineRenameState? { state.currentInlineRenameState }

    // ========================================================================
    // MARK: - Workspace Search / Call Hierarchy
    // ========================================================================

    /// 是否展示工作区符号搜索面板
    public var isWorkspaceSymbolSearchPresented: Bool { state.isWorkspaceSymbolSearchPresented }

    /// 是否展示调用层级面板
    public var isCallHierarchyPresented: Bool { state.isCallHierarchyPresented }

    // ========================================================================
    // MARK: - 文档大纲与折叠（Document Outline & Folding）
    // ========================================================================

    /// 刷新文档大纲
    public func refreshDocumentOutline() {
        state.refreshDocumentOutline()
    }

    /// 刷新折叠范围
    public func refreshFoldingRanges() {
        state.refreshFoldingRanges()
    }

    // ========================================================================
    // MARK: - 文档格式化（Document Formatting）
    // ========================================================================

    /// 使用 LSP 格式化当前文档
    public func formatDocumentWithLSP() async {
        await state.formatDocumentWithLSP()
    }

    // ========================================================================
    // MARK: - Quick Open
    // ========================================================================

    /// 解析 Quick Open 查询
    public func quickOpenQuery(for rawQuery: String) -> EditorQuickOpenQuery {
        state.quickOpenQuery(for: rawQuery)
    }

    /// 获取 Quick Open 结果列表
    public func editorQuickOpenItems(
        matching query: String,
        openEditors: [EditorOpenEditorItem],
        onOpenFile: @escaping (URL, CursorPosition?, Bool) -> Void
    ) async -> [EditorQuickOpenItemSuggestion] {
        await state.editorQuickOpenItems(
            matching: query,
            openEditors: openEditors,
            onOpenFile: onOpenFile
        )
    }

    // ========================================================================
    // MARK: - 命令系统（Command System - Advanced）
    // ========================================================================

    /// 执行编辑器命令（带调用上下文）
    func performCommand(id: String, invocationContext: EditorCommandInvocationContext) {
        state.performEditorCommand(id: id, invocationContext: invocationContext)
    }

    /// 获取命令展示模型
    public func editorCommandPresentationModel(matching query: String = "") -> EditorCommandPresentationModel {
        state.editorCommandPresentationModel(matching: query)
    }

    /// 获取命令展示模型（带调用上下文）
    func editorCommandPresentationModel(
        for invocationContext: EditorCommandInvocationContext,
        matching query: String = "",
        categories: Set<EditorCommandCategory>? = nil
    ) -> EditorCommandPresentationModel {
        state.editorCommandPresentationModel(
            for: invocationContext,
            matching: query,
            categories: categories
        )
    }

    /// 获取右键菜单展示模型
    func editorContextMenuPresentationModel(
        for invocationContext: EditorCommandInvocationContext,
        matching query: String = "",
        categories: Set<EditorCommandCategory>? = nil
    ) -> EditorCommandPresentationModel {
        state.editorContextMenuPresentationModel(
            for: invocationContext,
            matching: query,
            categories: categories
        )
    }

    /// 获取命令调用上下文
    func editorCommandInvocationContext(for textView: TextView?) -> EditorCommandInvocationContext {
        state.editorCommandInvocationContext(for: textView)
    }

    /// 获取首选命令面板分类
    public func preferredCommandPaletteCategory() -> EditorCommandCategory? {
        state.preferredCommandPaletteCategory()
    }

    /// 设置首选命令面板分类
    public func setPreferredCommandPaletteCategory(_ category: EditorCommandCategory?) {
        state.setPreferredCommandPaletteCategory(category)
    }

    // ========================================================================
    // MARK: - 主题管理（Theme Management）
    // ========================================================================

    /// 切换主题
    func setTheme(_ themeId: String) {
        state.setTheme(themeId)
    }

    /// 获取所有可用主题
    func availableThemes() -> [any SuperEditorThemeContributor] {
        state.availableThemes()
    }

    /// 由外层同步初始主题（ThemeStatusBarPlugin 调用）
    public func syncInitialThemeFromExternal(_ editorThemeId: String) {
        state.syncInitialThemeFromExternal(editorThemeId)
    }

    // ========================================================================
    // MARK: - 插件管理（Plugin Management）
    // ========================================================================

    /// 设置编辑器插件启用状态
    func setEditorFeaturePluginEnabled(_ pluginID: String, enabled: Bool) {
        state.setEditorFeaturePluginEnabled(pluginID, enabled: enabled)
    }

    /// 项目上下文能力
    public var projectContextCapability: (any SuperEditorProjectContextCapability)? {
        state.projectContextCapability
    }

    /// 语义能力
    public var semanticCapability: (any SuperEditorSemanticCapability)? {
        state.semanticCapability
    }

    // ========================================================================
    // MARK: - 内核视图桥接（Kernel View Bridge）
    //
    // ⚠️ 以下 API 仅供 SourceEditorView / SourceEditorViewBridge 等
    //    内核视图层使用。普通插件不应调用这些方法。
    // ========================================================================

    /// 当前编辑器状态（内核视图桥接用）
    public var editorState: SourceEditorState { state.editorState }

    /// 当前获得焦点的 TextView（内核视图桥接用）
    public var focusedTextView: TextView? {
        get { state.focusedTextView }
        set { state.focusedTextView = newValue }
    }

    /// 跳转定义代理（内核视图桥接用）
    public var jumpDelegate: EditorJumpToDefinitionDelegate? {
        get { state.jumpDelegate }
        set { state.jumpDelegate = newValue }
    }

    /// 面板状态（内核视图 / 底部面板插件用）
    public var panelState: EditorPanelState { state.panelState }

    /// 编辑器扩展注册中心（内核视图 / 扩展 Contributor 用）
    public var editorExtensions: EditorExtensionRegistry { state.editorExtensions }

    /// 调用层级提供者
    public var callHierarchyProvider: any SuperEditorCallHierarchyProvider { state.callHierarchyProvider }

    /// 工作区符号搜索提供者
    public var workspaceSymbolProvider: any SuperEditorWorkspaceSymbolProvider { state.workspaceSymbolProvider }

    /// 签名帮助提供者
    public var signatureHelpProvider: any SuperEditorSignatureHelpProvider { state.signatureHelpProvider }

    /// 内联提示提供者
    public var inlayHintProvider: any SuperEditorInlayHintProvider { state.inlayHintProvider }

    /// 文档高亮提供者
    public var documentHighlightProvider: any SuperEditorDocumentHighlightProvider { state.documentHighlightProvider }

    /// 折叠范围提供者
    public var foldingRangeProvider: any SuperEditorFoldingRangeProvider { state.foldingRangeProvider }

    /// 面板控制器（内核视图用）
    public var panelController: EditorPanelController { state.panelController }

    /// 执行工作区搜索
    public func performWorkspaceSearch() async {
        await state.performWorkspaceSearch()
    }

    /// 在编辑器中打开工作区搜索结果
    public func openWorkspaceSearchResultsInEditor() {
        state.openWorkspaceSearchResultsInEditor()
    }

    /// 打开工作区搜索匹配项
    public func openWorkspaceSearchMatch(_ match: EditorWorkspaceSearchMatch) {
        state.openWorkspaceSearchMatch(match)
    }

    // ========================================================================
    // MARK: - Session Snapshot Sync（内部协调）
    // ========================================================================

    /// 从快照同步活跃会话
    public func syncActiveSession(from snapshot: EditorSession) {
        sessionStore.syncActiveSession(from: snapshot)
    }

    // ========================================================================
    // MARK: - 通知桥接（Notification Bridge）
    // ========================================================================

    /// 活跃会话变化回调（可由宿主注册附加观察者）。
    public var onActiveSessionChanged: ((EditorSession) -> Void)? {
        get { activeSessionChangedObserver }
        set {
            activeSessionChangedObserver = newValue
            installActiveSessionSyncBridge()
        }
    }

    private func installActiveSessionSyncBridge() {
        state.onActiveSessionChanged = { [weak self] snapshot in
            guard let self else { return }
            self.sessionStore.syncActiveSession(from: snapshot)
            self.activeSessionChangedObserver?(snapshot)
        }
        sessionStore.syncActiveSession(from: state.activeSession)
    }
}
