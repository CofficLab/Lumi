import Foundation
import AppKit
import Combine
import MagicAlert
import CodeEditSourceEditor
import CodeEditTextView
import CodeEditLanguages
import LanguageServerProtocol
import UniformTypeIdentifiers
import MagicKit
import os

/// 编辑器状态管理器
/// 管理当前文件的内容（NSTextStorage）、光标位置、编辑器配置等
///
/// ## 状态拆分（P2.1）
/// - `uiState` — UI 配置（字体、主题、显示选项）
/// - `fileState` — 文件元数据与内容
/// - `panelState` — 面板显示状态（problems、references、hover 等）
/// - `editorState` — 编辑器底层状态（光标、滚动、查找）
///
/// ## 当前职责地图（Phase 12 Baseline）
/// - document: 文件加载、二进制/文本判定、保存、外部修改监听、LSP 文档生命周期
/// - session: `activeSession`、canonical selections、find/replace、scroll restore、undo/redo
/// - workbench-integration: `onActiveSessionChanged`、session snapshot 同步、open item / navigation 落点
/// - panel: problems / references / hover / workspace symbol / call hierarchy
/// - runtime: viewport render、large file mode、长行保护、runtime gating、overlay availability
/// - command: command palette、command context、registry refresh、toolbar/context menu dispatch
///
/// 所有 `@Published` 属性保留向后兼容，同时通过组合子状态容器实现关注点分离。
@MainActor
final class EditorState: ObservableObject, SuperLog {
    private final class SessionSyncGate {
        private var depth = 0

        var isSuspended: Bool { depth > 0 }

        func withSuspended(_ body: () -> Void) {
            depth += 1
            defer { depth = max(0, depth - 1) }
            body()
        }
    }

    nonisolated static let emoji = "📝"
    nonisolated static let verbose = true

    let logger = Logger(subsystem: "com.coffic.lumi", category: "editor.state")

    // MARK: - 组合子状态容器（P2.1）
    // 所有 @Published 属性通过 computed properties 桥接到子状态容器，
    // 保持向后兼容的同时实现关注点分离。

    /// UI 状态 — 字体、主题、显示选项、光标位置
    let uiState = EditorUIState()

    /// 文件状态 — 文件元数据、内容、语言检测、保存状态
    let fileState = EditorFileState()

    /// 面板状态 — Problems、References、Hover、符号搜索、调用层级
    let panelState = EditorPanelState()
    lazy var panelController = EditorPanelController(panelState: panelState)

    // MARK: - Problems

    /// 是否展示 Open Editors 面板
    @Published private(set) var isOpenEditorsPanelPresented: Bool = false

    /// 当前文件的诊断列表（Problems 面板数据源）
    @Published private(set) var problemDiagnostics: [Diagnostic] = []

    /// 当前文件的 Xcode 工程语义问题（Problems 面板附加数据源）
    @Published private(set) var semanticProblems: [EditorSemanticProblem] = []

    /// 是否正在重新解析 Xcode build context
    @Published private(set) var isResyncingXcodeBuildContext: Bool = false

    /// 当前选中的问题，用于列表高亮与编辑器同步
    @Published private(set) var selectedProblemDiagnostic: Diagnostic?

    /// 是否展示 Problems 面板
    @Published private(set) var isProblemsPanelPresented: Bool = false
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var canRedo: Bool = false

    /// 当前激活会话（Phase 2 起逐步替代散落的会话级状态）
    @Published private(set) var activeSession = EditorSession()
    @Published private(set) var findMatches: [EditorFindMatch] = []
    @Published private(set) var recentCommandIDs: [String] = []
    @Published private(set) var viewportVisibleLineRange: Range<Int> = 0..<0
    @Published private(set) var viewportRenderLineRange: Range<Int> = 0..<0
    private let runtimeModeController = EditorRuntimeModeController()
    private let commandController = EditorCommandController()
    let saveController = EditorSaveController()
    let externalFileController = EditorExternalFileController()
    private let configController = EditorConfigController()
    private let findController = EditorFindController()
    private let multiCursorController = EditorMultiCursorController()
    private let sessionController = EditorSessionController()
    private let cursorController = EditorCursorController()
    private let undoController = EditorUndoController()
    private let inputCommandController = EditorInputCommandController()
    private let textInputController = EditorTextInputController()
    let workspaceEditController = EditorWorkspaceEditController()
    let transactionController = EditorTransactionController()
    private let multiCursorWorkflowController = EditorMultiCursorWorkflowController()
    let lspActionController = EditorLSPActionController()
    let renameController = EditorRenameController()
    let formattingController = EditorFormattingController()
    let documentReplaceController = EditorDocumentReplaceController()
    let saveStateController = EditorSaveStateController()
    let externalFileWorkflowController = EditorExternalFileWorkflowController()
    let callHierarchyController = EditorCallHierarchyController()
    let saveWorkflowController = EditorSaveWorkflowController()
    let statusToastController = EditorStatusToastController()
    let fileWatcherController = EditorFileWatcherController()
    let languageActionFacade = EditorLanguageActionFacade()
    private let overlayController = EditorOverlayController()
    private let appearanceController = EditorAppearanceController()
    var viewportRenderController: ViewportRenderController { runtimeModeController.viewportRenderController }
    /// LSP viewport 调度器（inlay hints、diagnostics 等）
    var lspViewportScheduler: LSPViewportScheduler { runtimeModeController.lspViewportScheduler }

    var onActiveSessionChanged: ((EditorSession) -> Void)?

    private var diagnosticsCancellable: AnyCancellable?
    private var keybindingCancellable: AnyCancellable?
    private var xcodeContextCancellable: AnyCancellable?
    private var panelBindings = Set<AnyCancellable>()
    private var multiCursorSearchSession: EditorMultiCursorSearchSession?
    private let sessionSyncGate = SessionSyncGate()
    private var isRestoringUndoState = false
    let referencesRequestGeneration = RequestGeneration()
    private let editorUndoManager = EditorUndoManager()

    var savePipelineOptions: EditorSavePipelineOptions {
        saveController.pipelineOptions(
            trimTrailingWhitespace: trimTrailingWhitespaceOnSave,
            insertFinalNewline: insertFinalNewlineOnSave,
            formatOnSave: formatOnSave,
            organizeImportsOnSave: organizeImportsOnSave,
            fixAllOnSave: fixAllOnSave
        )
    }

    private func bindDiagnostics() {
        diagnosticsCancellable?.cancel()
        diagnosticsCancellable = lspService.$currentDiagnostics
            .receive(on: RunLoop.main)
            .sink { [weak self] diags in
                self?.panelController.setProblemDiagnostics(diags)
                if let selected = self?.panelState.selectedProblemDiagnostic,
                   diags.contains(where: { $0 == selected }) == false {
                    self?.panelController.setSelectedProblemDiagnostic(nil)
                }
                self?.syncActiveSessionState()
                // 面板打开时保持打开；面板关闭时不强制弹出
            }
    }

    private func bindPanelState() {
        panelBindings.removeAll()

        panelState.$problemDiagnostics
            .sink { [weak self] diagnostics in
                self?.problemDiagnostics = diagnostics
            }
            .store(in: &panelBindings)

        panelState.$semanticProblems
            .sink { [weak self] problems in
                self?.semanticProblems = problems
            }
            .store(in: &panelBindings)

        panelState.$isOpenEditorsPanelPresented
            .sink { [weak self] isPresented in
                self?.isOpenEditorsPanelPresented = isPresented
            }
            .store(in: &panelBindings)

        panelState.$selectedProblemDiagnostic
            .sink { [weak self] diagnostic in
                self?.selectedProblemDiagnostic = diagnostic
            }
            .store(in: &panelBindings)

        panelState.$isProblemsPanelPresented
            .sink { [weak self] isPresented in
                self?.isProblemsPanelPresented = isPresented
            }
            .store(in: &panelBindings)

        panelState.$referenceResults
            .sink { [weak self] results in
                self?.referenceResults = results.map(Self.referenceResult(from:))
            }
            .store(in: &panelBindings)

        panelState.$isReferencePanelPresented
            .sink { [weak self] isPresented in
                self?.isReferencePanelPresented = isPresented
            }
            .store(in: &panelBindings)

        panelState.$isWorkspaceSymbolSearchPresented
            .sink { [weak self] isPresented in
                self?.isWorkspaceSymbolSearchPresented = isPresented
            }
            .store(in: &panelBindings)

        panelState.$isCallHierarchyPresented
            .sink { [weak self] isPresented in
                self?.isCallHierarchyPresented = isPresented
            }
            .store(in: &panelBindings)

        panelState.$mouseHoverContent
            .sink { [weak self] content in
                self?.hoverText = content
                self?.mouseHoverContent = content
            }
            .store(in: &panelBindings)

        panelState.$mouseHoverSymbolRect
            .sink { [weak self] rect in
                self?.mouseHoverSymbolRect = rect
                self?.mouseHoverPoint = rect == .zero
                    ? .zero
                    : CGPoint(x: rect.midX, y: rect.midY)
                self?.mouseHoverLine = 0
                self?.mouseHoverCharacter = 0
            }
            .store(in: &panelBindings)

        syncPublishedPanelDataFromPanelState()
    }

    // MARK: - File State
    
    /// 当前文件 URL
    @Published private(set) var currentFileURL: URL? {
        didSet {
            refreshXcodeContextSnapshot()
        }
    }
    
    /// 当前文件内容（NSTextStorage，CodeEditSourceEditor 要求）
    @Published var content: NSTextStorage?

    /// Phase 1: 文档文本控制器，逐步收拢 buffer/textStorage 同步与事务应用
    let documentController = EditorDocumentController()
    
    /// LSP 服务实例（支持依赖注入，默认仍使用共享实例）
    let lspService: LSPService
    
    /// LSP 协调器（用于语言服务器集成）
    let lspCoordinator: LSPCoordinator
    /// 编辑器可消费的 LSP 抽象客户端（用于解耦具体实现）
    var lspClient: any EditorLSPClient { lspCoordinator }
    /// 当前编辑器链路绑定的 LSP 服务实例（供视图层注入）
    var lspServiceInstance: LSPService { lspService }
    /// 编辑器子插件管理器（负责补全/悬停/code action 等扩展点）
    let editorPluginManager: EditorPluginManager
    /// 已安装的编辑器插件信息（Phase 4: 从 installedPlugins 派生）
    var editorFeaturePlugins: [EditorPluginInfo] {
        editorPluginManager.installedPlugins.map { plugin in
            let type = type(of: plugin)
            return EditorPluginInfo(
                id: type.id,
                displayName: type.displayName,
                description: type.description,
                order: type.order,
                isConfigurable: type.isConfigurable,
                isEnabled: PluginVM.shared.isPluginEnabled(plugin)
            )
        }
    }

    struct EditorPluginInfo: Identifiable, Equatable {
        let id: String
        let displayName: String
        let description: String
        let order: Int
        let isConfigurable: Bool
        let isEnabled: Bool
    }

    /// 兼容旧调用：编辑器扩展注册中心
    var editorExtensions: EditorExtensionRegistry { editorPluginManager.registry }
    /// 后台扩展点解析器（异步聚合，去重/排序在后台线程执行）
    let editorExtensionResolver = ExtensionResolver.shared
    
    // MARK: - New LSP Providers
    
    /// 签名帮助提供者
    let signatureHelpProvider: SignatureHelpProvider
    /// 内联提示提供者
    let inlayHintProvider: InlayHintProvider
    /// 文档高亮提供者
    let documentHighlightProvider: DocumentHighlightProvider
    /// 代码动作提供者
    let codeActionProvider: CodeActionProvider
    /// 工作区符号搜索提供者
    let workspaceSymbolProvider: WorkspaceSymbolProvider
    /// 调用层级提供者
    let callHierarchyProvider: CallHierarchyProvider
    
    /// 跳转定义代理（右键和 Cmd+Click 共享）
    weak var jumpDelegate: EditorJumpToDefinitionDelegate?

    /// 当前获得焦点的 `TextView`（Code Action、Inlay 可见范围等）
    weak var focusedTextView: TextView?

    private var fullLoadOverrides: Set<URL> = []

    var isSyntaxHighlightingEnabledInViewport: Bool {
        Self.isViewportSyntaxFeatureEnabled(
            viewportRange: viewportRenderLineRange,
            maxLine: largeFileMode.maxSyntaxHighlightLines,
            largeFileMode: largeFileMode,
            longestDetectedLine: longestDetectedLine
        )
    }

    var areInlayHintsEnabledInViewport: Bool {
        !largeFileMode.isInlayHintsDisabled && isSyntaxHighlightingEnabledInViewport
    }

    var areDocumentHighlightsEnabled: Bool {
        isSyntaxHighlightingEnabledInViewport
    }

    var areHoversEnabled: Bool {
        isSyntaxHighlightingEnabledInViewport
    }

    var areSignatureHelpEnabled: Bool {
        isSyntaxHighlightingEnabledInViewport
    }

    var areCodeActionsEnabled: Bool {
        isSyntaxHighlightingEnabledInViewport
    }

    var canLoadFullFile: Bool {
        isTruncated && currentFileURL != nil
    }

    var isLongLineProtectionSuppressingSyntaxHighlighting: Bool {
        EditorRuntimeModeController.isLongLineProtectionSuppressingSyntaxHighlighting(
            largeFileMode: largeFileMode,
            longestDetectedLine: longestDetectedLine
        )
    }

    static func isLongLineProtectionSuppressingSyntaxHighlighting(
        largeFileMode: LargeFileMode,
        longestDetectedLine: LongestDetectedLine?
    ) -> Bool {
        EditorRuntimeModeController.isLongLineProtectionSuppressingSyntaxHighlighting(
            largeFileMode: largeFileMode,
            longestDetectedLine: longestDetectedLine
        )
    }

    static func isViewportSyntaxFeatureEnabled(
        viewportRange: Range<Int>,
        maxLine: Int,
        largeFileMode: LargeFileMode,
        longestDetectedLine: LongestDetectedLine?
    ) -> Bool {
        EditorRuntimeModeController.isViewportSyntaxFeatureEnabled(
            viewportRange: viewportRange,
            maxLine: maxLine,
            largeFileMode: largeFileMode,
            longestDetectedLine: longestDetectedLine
        )
    }

    static func isViewportFeatureEnabled(viewportRange: Range<Int>, maxLine: Int) -> Bool {
        EditorRuntimeModeController.isViewportFeatureEnabled(
            viewportRange: viewportRange,
            maxLine: maxLine
        )
    }

    func isRenderedLine(_ line: Int) -> Bool {
        runtimeModeController.isRenderedLine(line, renderRange: viewportRenderLineRange)
    }

    var isPrimaryCursorRendered: Bool {
        isRenderedLine(max(cursorLine - 1, 0))
    }

    func isRenderedOffset(_ offset: Int, lineTable: LineOffsetTable) -> Bool {
        runtimeModeController.isRenderedOffset(
            offset,
            renderRange: viewportRenderLineRange,
            lineTable: lineTable
        )
    }

    func intersectsRenderedRange(_ range: EditorRange, lineTable: LineOffsetTable) -> Bool {
        runtimeModeController.intersectsRenderedRange(
            range,
            renderRange: viewportRenderLineRange,
            lineTable: lineTable
        )
    }

    func renderedFindMatches(_ matches: [EditorFindMatch], lineTable: LineOffsetTable) -> [EditorFindMatch] {
        runtimeModeController.renderedFindMatches(
            matches,
            renderRange: viewportRenderLineRange,
            lineTable: lineTable
        )
    }

    func currentRenderedFindMatches(lineTable: LineOffsetTable) -> [EditorFindMatch] {
        renderedFindMatches(findMatches, lineTable: lineTable)
    }

    func renderedFindMatchHighlights(
        textView: TextView,
        lineTable: LineOffsetTable
    ) -> [FindMatchOverlayHighlight] {
        overlayController.findMatchHighlights(
            matches: currentRenderedFindMatches(lineTable: lineTable),
            selectedRange: activeSession.findReplaceState.selectedMatchRange,
            textView: textView,
            visibleRect: textView.visibleRect
        )
    }

    func renderedInlayHints(_ hints: [InlayHintItem]) -> [InlayHintItem] {
        runtimeModeController.renderedInlayHints(
            hints,
            renderRange: viewportRenderLineRange
        )
    }

    func renderedBracketMatch(lineTable: LineOffsetTable) -> BracketMatchResult? {
        guard let match = bracketMatchResult else { return nil }
        guard isRenderedOffset(match.openOffset, lineTable: lineTable),
              isRenderedOffset(match.closeOffset, lineTable: lineTable) else {
            return nil
        }
        return match
    }

    func renderedBracketOverlayRects(
        textView: TextView,
        lineTable: LineOffsetTable
    ) -> BracketOverlayRects? {
        overlayController.bracketOverlayRects(
            match: renderedBracketMatch(lineTable: lineTable),
            textView: textView
        )
    }

    var currentRenderedInlayHints: [InlayHintItem] {
        renderedInlayHints(inlayHintProvider.hints)
    }

    var shouldPresentInlayHintsStrip: Bool {
        !largeFileMode.isInlayHintsDisabled && !currentRenderedInlayHints.isEmpty
    }

    var shouldPresentHoverOverlay: Bool {
        overlayController.shouldPresentHoverOverlay(
            areHoversEnabled: areHoversEnabled,
            hasActiveHover: panelState.hasActiveHover,
            hoverText: panelState.mouseHoverContent
        )
    }

    var currentHoverOverlayText: String? {
        overlayController.hoverOverlayText(
            shouldPresent: shouldPresentHoverOverlay,
            hoverText: panelState.mouseHoverContent
        )
    }

    var currentHoverOverlayRect: CGRect {
        panelState.mouseHoverSymbolRect
    }

    var shouldCancelHoverForViewportTransition: Bool {
        panelState.hasActiveHover
    }

    func shouldCancelHoverForRuntimeAvailabilityChange(_ isEnabled: Bool) -> Bool {
        !isEnabled
    }

    func hoverOverlayOffset(
        in containerSize: CGSize,
        popoverHeight: CGFloat,
        maxWidth: CGFloat = 440,
        verticalGap: CGFloat = 4
    ) -> CGSize {
        overlayController.hoverOverlayOffset(
            symbolRect: panelState.mouseHoverSymbolRect,
            containerSize: containerSize,
            popoverHeight: popoverHeight,
            maxWidth: maxWidth,
            verticalGap: verticalGap
        )
    }

    var shouldUseTreeSitterHighlightProvider: Bool {
        isSyntaxHighlightingEnabledInViewport
    }

    var shouldUseSemanticTokenHighlightProvider: Bool {
        !largeFileMode.isSemanticTokensDisabled && isSyntaxHighlightingEnabledInViewport
    }

    var shouldUseDocumentHighlightProvider: Bool {
        areDocumentHighlightsEnabled
    }

    var shouldUsePluginHighlightProviders: Bool {
        isSyntaxHighlightingEnabledInViewport
    }

    var shouldPresentSignatureHelpOverlay: Bool {
        overlayController.shouldPresentSignatureHelpOverlay(
            areSignatureHelpEnabled: areSignatureHelpEnabled,
            isPrimaryCursorRendered: isPrimaryCursorRendered,
            currentHelp: signatureHelpProvider.currentHelp
        )
    }

    var currentSignatureHelpOverlayItem: SignatureHelpItem? {
        overlayController.signatureHelpOverlayItem(
            shouldPresent: shouldPresentSignatureHelpOverlay,
            currentHelp: signatureHelpProvider.currentHelp
        )
    }

    var shouldPresentCodeActionOverlay: Bool {
        overlayController.shouldPresentCodeActionOverlay(
            areCodeActionsEnabled: areCodeActionsEnabled,
            isVisible: codeActionProvider.isVisible,
            isPrimaryCursorRendered: isPrimaryCursorRendered
        )
    }

    var currentCodeActionOverlayActions: [CodeActionItem] {
        overlayController.codeActionOverlayActions(
            shouldPresent: shouldPresentCodeActionOverlay,
            actions: codeActionProvider.actions
        )
    }

    func performCodeActionOverlayAction(_ action: CodeActionItem) async {
        await codeActionProvider.performAction(
            action,
            textView: focusedTextView,
            documentURL: currentFileURL,
            applyWorkspaceEditViaTransaction: { [weak self] edit in
                self?.applyCodeActionWorkspaceEdit(edit)
            }
        ) { [weak self] message in
            self?.showStatusToast(message, level: .warning)
        }
        codeActionProvider.clear()
    }

    /// 在光标稳定后刷新可见区域内的 Inlay Hints
    func scheduleInlayHintsRefreshIfNeeded(controller: TextViewController) {
        scheduleInlayHintsRefreshIfNeeded(textView: controller.textView)
    }

    func handleViewportRuntimeTransition() {
        runtimeModeController.handleViewportRuntimeTransition(
            isPrimaryCursorRendered: isPrimaryCursorRendered,
            documentHighlightProvider: documentHighlightProvider,
            signatureHelpProvider: signatureHelpProvider,
            codeActionProvider: codeActionProvider
        )
    }

    func handleDocumentHighlightRuntimeAvailabilityChange(_ isEnabled: Bool) {
        runtimeModeController.handleDocumentHighlightRuntimeAvailabilityChange(
            isEnabled,
            documentHighlightProvider: documentHighlightProvider
        )
    }

    func handleSignatureHelpRuntimeAvailabilityChange(_ isEnabled: Bool) {
        runtimeModeController.handleSignatureHelpRuntimeAvailabilityChange(
            isEnabled,
            signatureHelpProvider: signatureHelpProvider
        )
    }

    func handleCodeActionRuntimeAvailabilityChange(_ isEnabled: Bool) {
        runtimeModeController.handleCodeActionRuntimeAvailabilityChange(
            isEnabled,
            codeActionProvider: codeActionProvider
        )
    }

    /// 在 viewport 或光标稳定后刷新可见区域内的 Inlay Hints
    func scheduleInlayHintsRefreshIfNeeded(textView: TextView?) {
        runtimeModeController.scheduleInlayHintsRefreshIfNeeded(
            textView: textView,
            lspSupportsInlayHints: lspService.supportsInlayHints,
            isInlayHintsEnabledInViewport: { [weak self] in
                self?.areInlayHintsEnabledInViewport ?? false
            },
            currentFileURL: { [weak self] in
                self?.currentFileURL
            },
            inlayHintProvider: inlayHintProvider
        )
    }
    
    /// 当前文件是否可编辑
    @Published var isEditable: Bool = true
    
    /// 当前文件是否为截断预览
    @Published var isTruncated: Bool = false
    
    /// 当前文件是否可预览
    @Published var canPreview: Bool = false

    /// 当前文件的大文件模式。
    @Published private(set) var largeFileMode: LargeFileMode = .normal

    /// 当前文档检测到的最长长行信息。
    @Published private(set) var longestDetectedLine: LongestDetectedLine?

    /// 当前文件是否为 Markdown 预览模式
    @Published var isMarkdownPreviewMode: Bool = false

    /// 当前文件是否为 Markdown 格式
    var isMarkdownFile: Bool {
        fileExtension == "md" || fileExtension == "mdx"
    }

    /// 当前文件是否为二进制/非文本文件（需要用 QuickLook 预览而非代码编辑器）
    @Published var isBinaryFile: Bool = false
    
    /// 文件扩展名
    @Published var fileExtension: String = ""
    
    /// 文件名
    @Published var fileName: String = ""
    
    /// 当前项目根路径（由 EditorRootView 设置，用于计算相对路径）
    var projectRootPath: String? {
        didSet {
            refreshXcodeContextSnapshot()
        }
    }

    /// 当前 Xcode 工程上下文快照（供 UI / 语言链路读取）
    @Published private(set) var xcodeContextSnapshot: XcodeEditorContextSnapshot?
    
    /// 当前文件相对于项目根目录的路径（用于构建选区位置信息）
    /// 若无项目则返回文件名
    var relativeFilePath: String {
        guard let url = currentFileURL else { return "" }
        guard let projectPath = projectRootPath else {
            return url.lastPathComponent
        }
        let absolutePath = url.path
        guard absolutePath.hasPrefix(projectPath) else {
            return url.lastPathComponent
        }
        var relative = String(absolutePath.dropFirst(projectPath.count))
        if relative.hasPrefix("/") {
            relative = String(relative.dropFirst())
        }
        return relative
    }

    @MainActor
    func refreshXcodeContextSnapshot() {
        guard let projectRootPath, !projectRootPath.isEmpty else {
            xcodeContextSnapshot = nil
            panelController.setSemanticProblems([])
            syncActiveSessionState()
            return
        }
        let bridge = XcodeProjectContextBridge.shared
        if let snapshot = bridge.makeEditorContextSnapshot(currentFileURL: currentFileURL),
           snapshot.projectPath == projectRootPath || snapshot.workspacePath.hasPrefix(projectRootPath) || projectRootPath.hasPrefix(snapshot.workspacePath) {
            xcodeContextSnapshot = snapshot
            bridge.updateLatestEditorSnapshot(snapshot)
            refreshXcodeSemanticProblems()
        } else {
            xcodeContextSnapshot = nil
            bridge.updateLatestEditorSnapshot(nil)
            panelController.setSemanticProblems([])
            syncActiveSessionState()
        }
    }

    @MainActor
    private func refreshXcodeSemanticProblems() {
        guard let snapshot = xcodeContextSnapshot, snapshot.isXcodeProject else {
            panelController.setSemanticProblems([])
            syncActiveSessionState()
            return
        }
        let report = XcodeSemanticAvailability.inspectCurrentFileContext(uri: currentFileURL?.absoluteString)
        panelController.setSemanticProblems(report.reasons.map(EditorSemanticProblem.init(reason:)))
        syncActiveSessionState()
    }
    
    // MARK: - Editor State
    
    /// 编辑器状态（光标位置、滚动位置、查找文本等）
    @Published var editorState = SourceEditorState()
    
    /// 当前行号
    @Published var cursorLine: Int = 1
    
    /// 当前列号
    @Published var cursorColumn: Int = 1

    // MARK: - Mouse Hover State

    /// 当前 LSP Hover 文本（光标移动触发，已废弃，保留兼容）
    @Published private(set) var hoverText: String?

    /// 鼠标悬停 Hover 内容（Markdown 格式）
    @Published private(set) var mouseHoverContent: String?

    /// 鼠标悬停对应的 symbol 矩形（编辑器坐标系，原点在左上角，Y 向下增长）
    /// 这个矩形精确覆盖 LSP 返回的 hover range 对应的文本区域
    @Published private(set) var mouseHoverSymbolRect: CGRect = .zero

    /// 鼠标悬停位置（编辑器坐标系，已废弃）
    @Published private(set) var mouseHoverPoint: CGPoint = .zero

    /// 鼠标悬停的 LSP 行列（已废弃）
    @Published private(set) var mouseHoverLine: Int = 0
    @Published private(set) var mouseHoverCharacter: Int = 0

    /// 设置鼠标悬停状态（使用 symbol 矩形定位）
    func setMouseHover(content: String, symbolRect: CGRect) {
        let currentContent = panelState.mouseHoverContent ?? ""
        let currentRect = panelState.mouseHoverSymbolRect
        let epsilon: CGFloat = 0.75
        let isSameContent = currentContent == content
        let isCloseRect = abs(currentRect.minX - symbolRect.minX) <= epsilon &&
            abs(currentRect.minY - symbolRect.minY) <= epsilon &&
            abs(currentRect.width - symbolRect.width) <= epsilon &&
            abs(currentRect.height - symbolRect.height) <= epsilon
        if isSameContent && isCloseRect { return }

        panelController.setMouseHover(content: content, symbolRect: symbolRect)
        syncActiveSessionState()
    }

    /// 清除鼠标悬停状态
    func clearMouseHover() {
        guard panelState.hasActiveHover else { return }
        if Self.verbose {
            EditorPlugin.logger.debug("\(Self.t)🚫 清除鼠标悬停")
        }
        panelController.clearMouseHover()
        syncActiveSessionState()
    }

    // MARK: - Bracket Matching

    /// 当前匹配的括号对位置（UTF-16 offset）。nil 表示光标不在括号旁边。
    @Published private(set) var bracketMatchResult: BracketMatchResult?

    /// 括号匹配结果
    /// 根据当前光标位置计算括号匹配
    func updateBracketMatch() {
        guard let text = content?.string else {
            bracketMatchResult = nil
            return
        }

        let cursorOffset: Int
        if multiCursorState.all.count == 1 {
            cursorOffset = multiCursorState.all.first?.location ?? 0
        } else if let focusedTextView,
                  let selection = focusedTextView.selectionManager.textSelections.first {
            cursorOffset = selection.range.location
        } else {
            cursorOffset = 0
        }

        let languageId = detectedLanguage?.tsName ?? "swift"
        let config = BracketPairsConfig.defaultForLanguage(languageId)

        if let match = BracketMatcher.findMatchingBracket(
            in: text, at: cursorOffset, config: config
        ) {
            bracketMatchResult = BracketMatchResult(
                openOffset: match.openPosition,
                closeOffset: match.closePosition
            )
        } else {
            bracketMatchResult = nil
        }
    }

    /// 多光标编辑状态
    @Published var multiCursorState = MultiCursorState()

    /// References 结果列表（右侧面板）
    @Published private(set) var referenceResults: [ReferenceResult] = []

    /// 是否展示 References 面板
    @Published private(set) var isReferencePanelPresented: Bool = false
    /// 是否展示工作区符号搜索面板
    @Published private(set) var isWorkspaceSymbolSearchPresented: Bool = false
    /// 是否展示调用层级面板
    @Published private(set) var isCallHierarchyPresented: Bool = false

    /// 总行数
    @Published var totalLines: Int = 0
    
    /// 检测到的语言
    @Published var detectedLanguage: CodeLanguage?
    
    // MARK: - Theme
    
    /// 当前主题 ID（与 EditorThemeContributor.id 对应）
    @Published var currentThemeId: String = "xcode-dark"
    
    /// 当前主题（缓存，避免每次重建）
    @Published private(set) var currentTheme: EditorTheme?
    
    // MARK: - Configuration
    
    /// 字体大小
    @Published var fontSize: Double = 13.0
    
    /// Tab 宽度
    @Published var tabWidth: Int = 4
    
    /// 是否使用空格替代 Tab
    @Published var useSpaces: Bool = true

    /// 保存时是否执行格式化
    @Published var formatOnSave: Bool = false

    /// 保存时是否执行 organize imports
    @Published var organizeImportsOnSave: Bool = false

    /// 保存时是否执行 source.fixAll
    @Published var fixAllOnSave: Bool = false

    /// 保存时是否去除行尾空白
    @Published var trimTrailingWhitespaceOnSave: Bool = true

    /// 保存时是否补最终换行
    @Published var insertFinalNewlineOnSave: Bool = true

    @Published var hasExternalFileConflict: Bool = false
    
    /// 是否自动换行
    @Published var wrapLines: Bool = true
    
    /// 是否显示 Minimap
    @Published var showMinimap: Bool = true
    
    /// 是否显示行号
    @Published var showGutter: Bool = true
    
    /// 是否显示代码折叠
    @Published var showFoldingRibbon: Bool = true

    /// 右侧面板宽度
    @Published var sidePanelWidth: CGFloat = 360
    
    // MARK: - Auto Save
    
    /// 是否有未保存的变更
    @Published var hasUnsavedChanges: Bool = false
    
    /// 保存状态
    @Published var saveState: EditorSaveState = .idle

    // MARK: - File Loading Constants
    
    /// 截断读取字节数（256KB）
    static let truncationReadBytes: Int = 256 * 1024
    
    // MARK: - Init
    
    init(lspService: LSPService = .shared) {
        self.lspService = lspService
        self.lspCoordinator = LSPCoordinator(lspService: lspService)
        self.editorPluginManager = EditorPluginManager()
        self.signatureHelpProvider = SignatureHelpProvider(lspService: lspService)
        self.inlayHintProvider = InlayHintProvider(lspService: lspService)
        self.documentHighlightProvider = DocumentHighlightProvider(lspService: lspService)
        self.codeActionProvider = CodeActionProvider(lspService: lspService)
        self.workspaceSymbolProvider = WorkspaceSymbolProvider(lspService: lspService)
        self.callHierarchyProvider = CallHierarchyProvider(lspService: lspService)
        self.codeActionProvider.editorExtensionRegistry = self.editorExtensions
        installEditorPluginsFromPluginVM()
        commandController.refreshCoreCommandRegistrations(in: self)
        bindKeybindings()
        bindPanelState()
        bindDiagnostics()
        restoreConfig()
        observeThemeChanges()
        observeXcodeContextChanges()
    }

    /// 从 PluginVM 过滤并安装编辑器插件（Phase 2）
    private func installEditorPluginsFromPluginVM() {
        let editorPlugins = PluginVM.shared.plugins.filter {
            PluginVM.shared.isPluginEnabled($0) && $0.providesEditorExtensions
        }
        editorPluginManager.install(plugins: editorPlugins)
    }

    private func bindKeybindings() {
        keybindingCancellable?.cancel()
        keybindingCancellable = commandController.observeCustomBindings { [weak self] in
            self?.refreshCoreCommandRegistrations()
        }
    }

    private func refreshCoreCommandRegistrations() {
        commandController.refreshCoreCommandRegistrations(in: self)
    }

    private func observeXcodeContextChanges() {
        xcodeContextCancellable?.cancel()
        xcodeContextCancellable = NotificationCenter.default
            .publisher(for: .lumiEditorXcodeContextDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshXcodeContextSnapshot()
            }
    }

    func setEditorFeaturePluginEnabled(_ pluginID: String, enabled: Bool) {
        PluginSettingsVM.shared.setPluginEnabled(pluginID, enabled: enabled)
    }

    func editorCommandSuggestions() -> [EditorCommandSuggestion] {
        refreshCoreCommandRegistrations()
        return commandController.commandSuggestions(
            state: self,
            registryContext: currentCommandContext(),
            legacySuggestions: legacyEditorCommandSuggestions()
        )
    }

    func editorCommandSuggestions(
        for context: EditorCommandContext,
        textView: TextView?
    ) -> [EditorCommandSuggestion] {
        refreshCoreCommandRegistrations()
        return commandController.commandSuggestions(
            state: self,
            registryContext: CommandRouter.commandContext(
                from: context,
                isEditorActive: currentFileURL != nil,
                isMultiCursor: multiCursorState.isEnabled
            ),
            legacyContext: context,
            textView: textView
        )
    }

    func editorCommandSections(matching query: String = "") -> [EditorCommandSection] {
        editorCommandPresentationModel(matching: query).sections
    }

    func editorCommandSections(
        for context: EditorCommandContext,
        textView: TextView?,
        matching query: String = ""
    ) -> [EditorCommandSection] {
        editorCommandPresentationModel(for: context, textView: textView, matching: query).sections
    }

    func editorCommandSections(
        from suggestions: [EditorCommandSuggestion],
        matching query: String = ""
    ) -> [EditorCommandSection] {
        editorCommandPresentationModel(from: suggestions, matching: query).sections
    }

    func editorCommandPresentationModel(matching query: String = "") -> EditorCommandPresentationModel {
        editorCommandPresentationModel(from: editorCommandSuggestions(), matching: query)
    }

    func editorCommandPresentationModel(
        for context: EditorCommandContext,
        textView: TextView?,
        matching query: String = "",
        categories: Set<EditorCommandCategory>? = nil
    ) -> EditorCommandPresentationModel {
        editorCommandPresentationModel(
            from: editorCommandSuggestions(for: context, textView: textView),
            matching: query,
            categories: categories
        )
    }

    func editorCommandPresentationModel(
        categories: Set<EditorCommandCategory>,
        matching query: String = ""
    ) -> EditorCommandPresentationModel {
        editorCommandPresentationModel(
            from: editorCommandSuggestions(),
            matching: query,
            categories: categories
        )
    }

    func editorCommandPresentationModel(
        from suggestions: [EditorCommandSuggestion],
        matching query: String = "",
        categories: Set<EditorCommandCategory>? = nil
    ) -> EditorCommandPresentationModel {
        commandController.presentationModel(
            from: suggestions,
            recentCommandIDs: recentCommandIDs,
            query: query,
            categories: categories
        )
    }

    func performEditorCommand(id: String) {
        refreshCoreCommandRegistrations()
        let didExecute = commandController.executeCommand(
            id: id,
            registryContext: currentCommandContext(),
            legacySuggestions: legacyEditorCommandSuggestions()
        )
        if didExecute {
            recordCommandExecution(id: id)
        }
    }

    func recordCommandExecution(id: String) {
        commandController.recordExecution(id: id, recentCommandIDs: &recentCommandIDs)
    }

    func recentCommandSuggestions(matching query: String = "", limit: Int = 5) -> [EditorCommandSuggestion] {
        Array(editorCommandPresentationModel(matching: query).recentCommands.prefix(limit))
    }

    func editorToolbarItems() -> [EditorToolbarItemSuggestion] {
        editorExtensions.toolbarItemSuggestions(state: self)
    }

    // MARK: - Config Persistence
    
    /// 从持久化存储恢复配置
    private func restoreConfig() {
        let snapshot = appearanceController.applyRestoredConfig(using: configController)
        fontSize = snapshot.fontSize
        tabWidth = snapshot.tabWidth
        useSpaces = snapshot.useSpaces
        formatOnSave = snapshot.formatOnSave
        organizeImportsOnSave = snapshot.organizeImportsOnSave
        fixAllOnSave = snapshot.fixAllOnSave
        trimTrailingWhitespaceOnSave = snapshot.trimTrailingWhitespaceOnSave
        insertFinalNewlineOnSave = snapshot.insertFinalNewlineOnSave
        wrapLines = snapshot.wrapLines
        showMinimap = snapshot.showMinimap
        showGutter = snapshot.showGutter
        showFoldingRibbon = snapshot.showFoldingRibbon
        sidePanelWidth = snapshot.sidePanelWidth
        currentThemeId = snapshot.currentThemeId
        currentTheme = resolveTheme(for: currentThemeId)
    }
    
    /// 持久化当前配置
    func persistConfig() {
        configController.persistConfig(
            EditorConfigSnapshot(
                fontSize: fontSize,
                tabWidth: tabWidth,
                useSpaces: useSpaces,
                formatOnSave: formatOnSave,
                organizeImportsOnSave: organizeImportsOnSave,
                fixAllOnSave: fixAllOnSave,
                trimTrailingWhitespaceOnSave: trimTrailingWhitespaceOnSave,
                insertFinalNewlineOnSave: insertFinalNewlineOnSave,
                wrapLines: wrapLines,
                showMinimap: showMinimap,
                showGutter: showGutter,
                showFoldingRibbon: showFoldingRibbon,
                currentThemeId: currentThemeId,
                sidePanelWidth: sidePanelWidth
            )
        )
    }
    
    /// 切换主题
    func setTheme(_ themeId: String) {
        currentThemeId = themeId
        currentTheme = resolveTheme(for: themeId)
        persistConfig()

        // 通知终端插件同步更新颜色
        NotificationCenter.default.post(
            name: .lumiEditorThemeDidChange,
            object: nil,
            userInfo: ["themeId": themeId]
        )
    }

    /// 同步主题但不触发持久化和通知（用于 hosted state 同步）
    func syncThemeSilently(_ themeId: String) {
        guard appearanceController.syncThemeSilently(
            currentThemeId: currentThemeId,
            incomingThemeId: themeId
        ) else { return }
        currentThemeId = themeId
        currentTheme = resolveTheme(for: themeId)
    }

    /// 获取所有可用主题
    func availableThemes() -> [any EditorThemeContributor] {
        editorExtensions.allThemes()
    }

    /// 根据主题 ID 解析 EditorTheme
    /// 优先从插件系统获取，fallback 到 EditorThemeAdapter 默认主题
    private func resolveTheme(for id: String) -> EditorTheme {
        if let contributor = editorExtensions.theme(for: id) {
            return contributor.createTheme()
        }
        // Fallback：插件系统未加载时使用默认 Xcode Dark 主题
        return EditorThemeAdapter.fallbackTheme()
    }

    /// 监听全局主题变更通知（来自底部状态栏的主题切换）
    private func observeThemeChanges() {
        configController.observeThemeChanges { [weak self] themeId, shouldRegisterThemeContributors in
            guard let self else { return }
            if shouldRegisterThemeContributors {
                let allContributions = PluginVM.shared.getThemeContributions()
                for contribution in allContributions {
                    if let c = contribution.editorThemeContributor as? any EditorThemeContributor {
                        self.editorExtensions.registerThemeContributor(c)
                    }
                }
            }
            guard self.currentThemeId != themeId else { return }
            self.currentThemeId = themeId
            self.currentTheme = self.resolveTheme(for: themeId)
        }
    }
    
    // MARK: - File Loading
    
    /// 加载指定文件
    func loadFile(from url: URL?) {
        // 清理旧状态
        referencesRequestGeneration.invalidate()
        saveController.cancelSuccessClear()
        
        guard let url = url else {
            resetState()
            return
        }
        
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        if isDirectory {
            resetState()
            return
        }
        
        let loadingURL = url
        
        Task {
            do {
                let loadedDocument = try documentController.loadDocument(
                    from: url,
                    truncationReadBytes: Self.truncationReadBytes,
                    forceFullLoad: fullLoadOverrides.contains(loadingURL.standardizedFileURL)
                )
                
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    let standardizedLoadingURL = loadingURL.standardizedFileURL
                    let isReloadingCurrentFile = self.currentFileURL?.standardizedFileURL == standardizedLoadingURL
                    let shouldReplaceCurrentBuffer = !isReloadingCurrentFile || self.content == nil || self.fullLoadOverrides.contains(standardizedLoadingURL)
                    guard shouldReplaceCurrentBuffer else { return }
                    switch loadedDocument {
                    case .binary:
                        self.loadBinaryFile(from: loadingURL, loadedDocument: loadedDocument)
                    case .text(let document):
                        let content = document.content
                        let longestLine = LongLineDetector.findLongestLine(in: content)
                        self.withoutSessionSync {
                            self.currentFileURL = loadingURL
                            _ = self.documentController.load(text: content)
                            self.documentController.markPersistedText(content)
                            self.content = self.documentController.textStorage
                            self.canPreview = true
                            self.isBinaryFile = false
                            self.largeFileMode = document.largeFileMode
                            self.longestDetectedLine = longestLine
                            self.isEditable = !document.isTruncated && !document.largeFileMode.isReadOnly
                            self.isTruncated = document.isTruncated
                            self.fileExtension = document.fileExtension
                            self.fileName = document.fileName
                            self.hasUnsavedChanges = false
                            self.saveState = .idle

                            self.detectedLanguage = CodeLanguage.detectLanguageFrom(
                                url: loadingURL,
                                prefixBuffer: content.getFirstLines(5),
                                suffixBuffer: content.getLastLines(5)
                            )

                            if self.detectedLanguage == nil || self.detectedLanguage?.id == .plainText {
                                let fallbackMap: [String: CodeLanguage] = [
                                    "astro": .tsx,
                                    "vue": .tsx,
                                    "svelte": .tsx,
                                    "astro-component": .tsx,
                                ]
                                if let fallback = fallbackMap[self.fileExtension] {
                                    self.detectedLanguage = fallback
                                }
                            }

                            self.totalLines = content.filter { $0 == "\n" }.count + 1
                            self.resetViewportObservation(totalLines: self.totalLines)
                            self.inlayHintProvider.clear()
                            self.codeActionProvider.clear()
                            self.runtimeModeController.cancelPendingInlayHintsRefresh()
                            self.panelController.clearData(
                                closeProblems: false,
                                closeReferences: false
                            )
                        }
                        self.syncActiveSessionState()
                        self.resetUndoHistory()
                        self.setupFileWatcher(for: loadingURL)

                        let languageId = self.detectedLanguage?.id.rawValue ?? self.lspActionController.languageID(for: self.fileExtension)
                        if let languageId {
                            let rootPath = self.projectRootPath ?? loadingURL.deletingLastPathComponent().path
                            EditorPlugin.logger.info(
                                "\(Self.t)LSP openFile 准备: file=\(loadingURL.path, privacy: .public), languageId=\(languageId, privacy: .public), projectRoot=\(self.projectRootPath ?? "<nil>", privacy: .public), chosenRoot=\(rootPath, privacy: .public)"
                            )
                            self.lspCoordinator.setProjectRootPath(rootPath)
                            let documentVersion = self.currentDocumentVersion
                            Task {
                                await self.lspCoordinator.openFile(
                                    uri: loadingURL.absoluteString,
                                    languageId: languageId,
                                    content: content,
                                    version: documentVersion
                                )
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.resetState()
                }
            }
        }
    }

    func loadFullFileFromDisk() {
        guard let currentFileURL else { return }
        fullLoadOverrides.insert(currentFileURL.standardizedFileURL)
        loadFile(from: currentFileURL)
    }

    func applySessionRestore(_ session: EditorSession) {
        let fallbackCursorPositions = multiCursorCursorPositions(from: session.multiCursorState.all)
        let restore = sessionController.restoreApplication(
            from: session,
            fallbackCursorPositions: fallbackCursorPositions
        )

        multiCursorState = restore.multiCursorState
        panelController.restore(from: restore.panelState)
        applyResolvedInteractionUpdate(restore.resolvedInteraction)
        sessionController.restoreScrollState(restore.scrollState, in: focusedTextView)
    }

    func applyFindReplaceObservation(_ state: EditorFindReplaceState) {
        applyInteractionUpdate(
            .findReplace(state)
        )
    }

    func openFindPanel() {
        var state = activeSession.findReplaceState
        if state.findText.isEmpty,
           let selectedText = currentSelectedPlainText(),
           !selectedText.isEmpty {
            state.findText = selectedText
        }
        applyFindReplaceObservation(
            findController.stateForOpeningPanel(state)
        )
    }

    func closeFindPanel() {
        applyFindReplaceObservation(
            findController.stateForClosingPanel(activeSession.findReplaceState)
        )
    }

    func toggleFindPanel() {
        activeSession.findReplaceState.isFindPanelVisible ? closeFindPanel() : openFindPanel()
    }

    func updateFindQuery(_ text: String) {
        applyFindReplaceObservation(
            findController.stateForUpdatingFindQuery(
                activeSession.findReplaceState,
                text: text
            )
        )
    }

    func updateReplaceQuery(_ text: String) {
        applyFindReplaceObservation(
            findController.stateForUpdatingReplaceQuery(
                activeSession.findReplaceState,
                text: text
            )
        )
    }

    func applySourceEditorBindingUpdate(_ update: EditorSourceEditorBindingUpdate) {
        applyInteractionUpdate(
            .sourceEditorBinding(update)
        )
    }

    func applyScrollObservation(viewportOrigin: CGPoint) {
        applyInteractionUpdate(
            .scroll(EditorScrollState(viewportOrigin: viewportOrigin))
        )
    }

    func applyViewportObservation(startLine: Int, endLine: Int, totalLines: Int) {
        let observation = runtimeModeController.applyViewportObservation(
            startLine: startLine,
            endLine: endLine,
            totalLines: totalLines,
            areInlayHintsEnabled: areInlayHintsEnabledInViewport,
            requestInlayHints: { [weak self] in
                self?.requestInlayHintsForVisibleRange()
            },
            clearInlayHints: { [weak self] in
                self?.inlayHintProvider.clear()
            }
        )
        viewportVisibleLineRange = observation.visibleLineRange
        viewportRenderLineRange = observation.renderLineRange
    }

    /// 对可见区域发起 inlay hint 请求（由 LSPViewportScheduler 调度后调用）
    private func requestInlayHintsForVisibleRange() {
        runtimeModeController.requestInlayHintsForVisibleRange(
            lspSupportsInlayHints: lspService.supportsInlayHints,
            areInlayHintsEnabledInViewport: areInlayHintsEnabledInViewport,
            currentFileURL: currentFileURL,
            focusedTextView: focusedTextView,
            inlayHintProvider: inlayHintProvider
        )
    }

    func resetViewportObservation(totalLines: Int = 0) {
        let observation = runtimeModeController.resetViewportObservation(totalLines: totalLines)
        viewportVisibleLineRange = observation.visibleLineRange
        viewportRenderLineRange = observation.renderLineRange
    }

    private func applyInteractionUpdate(_ update: EditorInteractionUpdate) {
        let resolved = sessionController.resolveInteractionUpdate(
            update,
            currentBridgeState: currentBridgeState()
        )
        applyResolvedInteractionUpdate(resolved)
    }

    private func applyResolvedInteractionUpdate(_ resolved: ResolvedEditorInteractionUpdate) {
        if let bridgeState = resolved.bridgeState {
            applyBridgeState(bridgeState)
        }

        syncActiveSessionState(
            scrollStateOverride: resolved.scrollState
        )

        if resolved.bridgeState?.findReplaceState != nil {
            refreshFindMatches()
        }
    }

    func updateFindReplaceOptions(_ transform: (inout EditorFindReplaceOptions) -> Void) {
        applyFindReplaceObservation(
            findController.stateForUpdatingOptions(
                activeSession.findReplaceState,
                transform: transform
            )
        )
    }

    func refreshFindMatches() {
        guard let text = content?.string else {
            applyFindMatchesResult(
                EditorFindMatchesResult(matches: [], selectedMatchIndex: nil, selectedMatchRange: nil)
            )
            return
        }

        let currentState = activeSession.findReplaceState
        let selections = multiCursorState.all.map {
            EditorSelection(range: EditorRange(location: $0.location, length: $0.length))
        }
        let result = findController.matchesResult(
            state: currentState,
            text: text,
            selections: selections
        )
        applyFindMatchesResult(result)
    }

    func selectNextFindMatch() {
        guard let nextIndex = findController.nextMatchIndex(
            matches: findMatches,
            selectedMatchIndex: activeSession.findReplaceState.selectedMatchIndex
        ) else { return }
        selectFindMatch(at: nextIndex)
    }

    func selectPreviousFindMatch() {
        guard let previousIndex = findController.previousMatchIndex(
            matches: findMatches,
            selectedMatchIndex: activeSession.findReplaceState.selectedMatchIndex
        ) else { return }
        selectFindMatch(at: previousIndex)
    }

    func replaceCurrentFindMatch() {
        guard let transaction = findController.replaceCurrentTransaction(
            state: activeSession.findReplaceState,
            matches: findMatches
        ) else { return }
        applyEditorTransaction(transaction, reason: "find_replace_current")
        refreshFindMatches()
    }

    func replaceAllFindMatches() {
        guard let transaction = findController.replaceAllTransaction(
            state: activeSession.findReplaceState,
            matches: findMatches
        ) else { return }
        applyEditorTransaction(transaction, reason: "find_replace_all")
        refreshFindMatches()
    }

    func performPanelCommand(_ command: EditorPanelCommand) {
        panelController.apply(command: command)
        syncActiveSessionState()
    }

    func updateSelectedProblemDiagnostic(for cursor: CursorPosition?) {
        panelController.updateSelectedProblemDiagnostic(
            line: cursor?.start.line,
            column: cursor?.start.column
        )
    }

    func applyCursorObservation(_ positions: [CursorPosition]) {
        applyInteractionUpdate(
            cursorController.observationUpdate(
                positions: positions,
                fallbackLine: max(cursorLine, 1),
                fallbackColumn: max(cursorColumn, 1)
            )
        )
        updateBracketMatch()
    }

    func applyPrimaryCursorObservation(line: Int, column: Int) {
        updatePrimaryCursorPosition(
            line: line,
            column: column,
            preserveCursorSelection: true
        )
        // 括号匹配需要在每次光标移动时更新
        updateBracketMatch()
    }

    func navigateToCursorPositions(_ positions: [CursorPosition]) {
        applyInteractionUpdate(cursorController.explicitPositionsUpdate(positions))
    }

    private func updatePrimaryCursorPosition(
        line: Int,
        column: Int,
        preserveCursorSelection: Bool = true
    ) {
        applyInteractionUpdate(
            cursorController.primaryPositionUpdate(
                line: line,
                column: column,
                existingPositions: editorState.cursorPositions ?? [],
                preserveCursorSelection: preserveCursorSelection
            )
        )
    }

    func resetPrimaryCursorPosition() {
        applyInteractionUpdate(cursorController.resetPrimaryCursor(in: &editorState))
    }

    /// 执行导航请求并在目标文件/位置落点
    func performNavigation(_ request: EditorNavigationRequest) {
        let resolved = EditorNavigationController.resolve(request)
        loadFile(from: resolved.url)
        Task { @MainActor [weak self] in
            guard let self else { return }
            for _ in 0..<40 {
                if self.currentFileURL == resolved.url, self.content != nil {
                    let finalTarget = EditorNavigationController.resolvedDefinitionTarget(
                        from: resolved.target,
                        highlightLine: resolved.highlightLine,
                        content: self.content?.string
                    )
                    self.navigateToCursorPositions([finalTarget])
                    return
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
            let finalTarget = EditorNavigationController.resolvedDefinitionTarget(
                from: resolved.target,
                highlightLine: resolved.highlightLine,
                content: self.content?.string
            )
            self.navigateToCursorPositions([finalTarget])
        }
    }

    func performOpenItem(_ command: EditorOpenItemCommand) {
        guard let resolved = EditorOpenItemCommandController.resolve(command) else {
            switch command {
            case .workspaceSymbol:
                showStatusToast("无法打开符号位置", level: .warning)
            case .callHierarchyItem:
                showStatusToast("无法打开调用层级目标", level: .warning)
            case .problem, .reference:
                break
            }
            return
        }

        if let diagnostic = resolved.selectedProblemDiagnostic {
            panelController.setSelectedProblemDiagnostic(diagnostic)
        }
        if !resolved.cursorPositions.isEmpty {
            navigateToCursorPositions(resolved.cursorPositions)
        }
        if resolved.closeWorkspaceSymbolSearch {
            performPanelCommand(.closeWorkspaceSymbolSearch)
        }
        if let navigationRequest = resolved.navigationRequest {
            performNavigation(navigationRequest)
        }
    }
    
    /// 重置状态
    private func resetState() {
        referencesRequestGeneration.invalidate()
        sessionSyncGate.withSuspended {
            currentFileURL = nil
            content = nil
            documentController.clear()
            content = documentController.textStorage
            activeSession.reset()
            canPreview = false
            isBinaryFile = false
            isEditable = true
            isTruncated = false
            fileExtension = ""
            fileName = ""
            hasUnsavedChanges = false
            saveState = .idle
            detectedLanguage = nil
            largeFileMode = .normal
            longestDetectedLine = nil
            resetViewportObservation()
            resetPrimaryCursorPosition()
            totalLines = 0
            panelController.clearData(
                clearDiagnostics: true,
                closeProblems: false,
                closeReferences: false,
                closeWorkspaceSymbols: false,
                closeCallHierarchy: false
            )
            inlayHintProvider.clear()
            codeActionProvider.clear()
            runtimeModeController.cancelPendingInlayHintsRefresh()
            focusedTextView = nil
        }
        
        // 清理文件监听器
        cleanupFileWatcher()
        
        // 关闭 LSP 文档
        lspCoordinator.closeFile()
        resetUndoHistory()
        syncActiveSessionState()
    }
    
    /// 加载二进制/非文本文件进行预览
    /// 不尝试解析内容，只设置文件元数据，供 QuickLook 预览使用
    func loadBinaryFile(from url: URL) {
        loadBinaryFile(from: url, loadedDocument: nil)
    }

    private func loadBinaryFile(
        from url: URL,
        loadedDocument: EditorDocumentController.LoadedDocument?
    ) {
        // 清理旧状态
        referencesRequestGeneration.invalidate()
        saveController.cancelSuccessClear()
        cleanupFileWatcher()
        lspCoordinator.closeFile()
        
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        if isDirectory {
            resetState()
            return
        }

        let binaryDocument: EditorDocumentController.LoadedBinaryDocument
        if case .binary(let document) = loadedDocument {
            binaryDocument = document
        } else {
            let fileSize = Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            binaryDocument = .init(
                fileSize: fileSize,
                largeFileMode: LargeFileMode.mode(for: fileSize),
                fileExtension: url.pathExtension.lowercased(),
                fileName: url.lastPathComponent
            )
        }
        
        sessionSyncGate.withSuspended {
            currentFileURL = url
            documentController.clear()
            documentController.clearPersistedTextSnapshot()
            content = documentController.textStorage
            canPreview = false
            isBinaryFile = true
            isEditable = false
            isTruncated = false
            largeFileMode = binaryDocument.largeFileMode
            longestDetectedLine = nil
            resetViewportObservation()
            fileExtension = binaryDocument.fileExtension
            fileName = binaryDocument.fileName
            hasUnsavedChanges = false
            saveState = .idle
            detectedLanguage = nil
            resetPrimaryCursorPosition()
            totalLines = 0
            panelController.clearData(
                clearDiagnostics: true,
                closeProblems: false,
                closeReferences: false,
                closeWorkspaceSymbols: false,
                closeCallHierarchy: false
            )
        }
        
        // 计算文件大小显示信息
        let sizeText = ByteCountFormatter.string(fromByteCount: binaryDocument.fileSize, countStyle: .file)
        if Self.verbose {
            logger.info("\(Self.t)加载二进制文件: \(url.lastPathComponent), 大小: \(sizeText)")
        }
        resetUndoHistory()
        syncActiveSessionState()
    }
    
    // MARK: - Content Change Detection
    
    private func refreshContentDerivedState(using contentString: String) {
        let changed = documentController.hasChangesComparedToPersistedSnapshot(contentString)

        if Self.verbose {
            logger.info("\(Self.t)内容变更检测: changed=\(changed), 内容长度=\(contentString.count), 快照长度=\(self.documentController.persistedTextSnapshot?.count ?? -1), 文件=\(self.currentFileURL?.lastPathComponent ?? "nil")")
        }

        if changed {
            hasUnsavedChanges = true
            saveState = .editing
            lspCoordinator.updateDocumentSnapshot(contentString)
        } else {
            hasUnsavedChanges = false
            saveState = .idle
        }
        refreshFindMatches()
        syncActiveSessionState()
        updateBracketMatch()
    }

    func notifyContentChangedAfterSynchronizedEdit(using contentString: String) {
        refreshContentDerivedState(using: contentString)
    }

    func notifyContentChanged(fromTextViewString text: String) {
        if documentController.currentText == text {
            notifyContentChangedAfterSynchronizedEdit(using: text)
        } else {
            let result = documentController.replaceText(text)
            content = documentController.textStorage
            totalLines = result.snapshot.text.filter { $0 == "\n" }.count + 1
            if viewportVisibleLineRange.isEmpty {
                resetViewportObservation(totalLines: totalLines)
            }
            notifyContentChangedAfterSynchronizedEdit(using: result.snapshot.text)
        }
    }

    /// 通知内容已变更（由 TextViewCoordinator 调用）
    func notifyContentChanged() {
        guard let textStorage = content else {
            if Self.verbose {
                logger.warning("\(Self.t)内容变更: content 为 nil，无法检测变更")
            }
            return
        }
        
        let contentString = textStorage.string
        if let result = documentController.syncBufferFromTextStorageIfNeeded() {
            content = documentController.textStorage
            totalLines = result.snapshot.text.filter { $0 == "\n" }.count + 1
            if viewportVisibleLineRange.isEmpty {
                resetViewportObservation(totalLines: totalLines)
            }
        }
        notifyContentChangedAfterSynchronizedEdit(using: contentString)
    }

    func applyNativeTextEdit(range: NSRange, text: String, textViewString: String? = nil) {
        if let result = documentController.applyTextStorageEdit(range: range, text: text) {
            content = documentController.textStorage
            totalLines = result.snapshot.text.filter { $0 == "\n" }.count + 1
            if viewportVisibleLineRange.isEmpty {
                resetViewportObservation(totalLines: totalLines)
            }
            notifyContentChangedAfterSynchronizedEdit(using: result.snapshot.text)
        } else if let textViewString {
            notifyContentChanged(fromTextViewString: textViewString)
        } else {
            notifyContentChanged()
        }
    }

    func captureUndoState() -> EditorUndoState {
        undoController.captureState(
            currentText: documentController.currentText ?? content?.string ?? "",
            selections: canonicalSelectionSet.selections
        )
    }

    func recordUndoChange(from before: EditorUndoState, reason: String) {
        let after = captureUndoState()
        let availability = undoController.recordChange(
            in: editorUndoManager,
            from: before,
            to: after,
            reason: reason,
            isRestoringUndoState: isRestoringUndoState
        )
        canUndo = availability.canUndo
        canRedo = availability.canRedo
    }

    func performUndo() {
        guard let result = undoController.performUndo(in: editorUndoManager) else { return }
        applyUndoState(result.state)
        canUndo = result.canUndo
        canRedo = result.canRedo
    }

    func performRedo() {
        guard let result = undoController.performRedo(in: editorUndoManager) else { return }
        applyUndoState(result.state)
        canUndo = result.canUndo
        canRedo = result.canRedo
    }
    
    /// 通知 LSP 发生增量文本变更（由编辑器 coordinator 转发）
    func notifyLSPIncrementalChange(range: LSPRange, text: String) {
        lspCoordinator.contentDidChange(range: range, text: text, version: currentDocumentVersion)
    }

    // MARK: - LSP Actions

    /// 执行文档格式化（LSP formatting）
    func formatDocumentWithLSP() async {
        if let preflightMessage = xcodeLanguagePreflightMessage(operation: "格式化文档") {
            showStatusToast(preflightMessage, level: .warning, duration: 2.4)
            return
        }
        await languageActionFacade.formatDocument(
            formattingController: formattingController,
            canPreview: canPreview,
            isEditable: isEditable,
            tabSize: tabWidth,
            insertSpaces: useSpaces,
            requestFormatting: { [weak self] tabSize, insertSpaces in
                guard let self else { return nil }
                return await self.lspCoordinator.requestFormatting(
                    tabSize: tabSize,
                    insertSpaces: insertSpaces
                )
            },
            applyTextEdits: { [weak self] edits, reason in
                self?.applyTextEditsToCurrentDocument(edits, reason: reason)
            },
            showStatus: { [weak self] message, level, duration in
                self?.showStatusToast(message, level: level, duration: duration)
            }
        )
    }

    func updateSidePanelWidth(by delta: CGFloat) {
        sidePanelWidth = appearanceController.updateSidePanelWidth(
            currentWidth: sidePanelWidth,
            delta: delta
        )
    }

    func persistSidePanelWidth() {
        appearanceController.persistSidePanelWidth(sidePanelWidth)
    }

    // MARK: - LSP Helpers
    
    // MARK: - LSP Edit Utilities

    func clearMultiCursors() {
        applyMultiCursorWorkflowResult(
            multiCursorWorkflowController.clearedState(
                currentState: multiCursorState,
                using: multiCursorController
            )
        )
    }

    func clearUnfocusedMultiCursorsIfNeeded() {
        guard multiCursorState.isEnabled else { return }
        guard multiCursorState.all.count <= 1 else { return }
        applyMultiCursorWorkflowResult(
            multiCursorWorkflowController.clearedState(
                currentState: multiCursorState,
                using: multiCursorController
            ),
            shouldLog: false
        )
    }

    func setPrimarySelection(_ selection: MultiCursorSelection) {
        applyMultiCursorWorkflowResult(
            multiCursorWorkflowController.primarySelectionState(
                selection,
                currentState: multiCursorState,
                using: multiCursorController
            )
        )
    }

    func setSelections(_ selections: [MultiCursorSelection]) {
        guard let result = multiCursorWorkflowController.setSelectionsResult(
            selections,
            existingSession: multiCursorSearchSession,
            text: currentEditorTextStorageString(),
            using: multiCursorController
        ) else {
            clearMultiCursors()
            return
        }
        applyMultiCursorWorkflowResult(result)
    }

    func currentSelectionsAsNSRanges() -> [NSRange] {
        multiCursorController.nsRanges(from: multiCursorState)
    }

    private func applyMultiCursorSelections(_ selections: [MultiCursorSelection]) {
        applyMultiCursorState(multiCursorController.state(from: selections))
    }

    private func applyMultiCursorState(_ state: MultiCursorState) {
        multiCursorState = state
        let selections = state.all
        if selections.isEmpty {
            navigateToCursorPositions([])
            return
        }
        syncEditorCursorPositionsFromSelections(selections)
    }

    private func syncEditorCursorPositionsFromSelections(_ selections: [MultiCursorSelection]) {
        guard let text = content?.string else {
            navigateToCursorPositions([])
            return
        }

        let cursorPositions = multiCursorController.cursorPositions(
            from: selections,
            text: text,
            fallbackLine: max(cursorLine, 1),
            fallbackColumn: max(cursorColumn, 1),
            positionResolver: editorPosition(utf16Offset:in:)
        )
        navigateToCursorPositions(cursorPositions)
    }

    func logMultiCursorState(action: String, note: String? = nil) {
        let message = multiCursorController.stateLogMessage(
            action: action,
            selections: multiCursorState.all,
            note: note
        )
        EditorPlugin.logger.info("[UI] | ✏️ 编辑器状态 | 多光标状态 | \(message, privacy: .public)")
    }

    func logMultiCursorInput(action: String, textViewSelections: [NSRange], note: String? = nil) {
        let details = multiCursorController.inputLogMessage(
            action: action,
            textViewSelections: textViewSelections,
            note: note
        )
        EditorPlugin.logger.info("[UI] | ✏️ 编辑器状态 | 多光标输入 | \(details, privacy: .public)")
        logMultiCursorState(action: "input-state-sync", note: action)
    }

    func addNextOccurrence() {
        let range = NSRange(
            location: multiCursorState.primary.location,
            length: multiCursorState.primary.length
        )
        _ = addNextOccurrence(from: range)
    }

    @discardableResult
    func addNextOccurrence(from range: NSRange) -> [NSRange]? {
        guard let text = currentEditorTextStorageString(),
              let result = multiCursorWorkflowController.addNextOccurrenceResult(
            from: range,
            currentState: multiCursorState,
            existingSession: multiCursorSearchSession,
            text: text,
            using: multiCursorController
        ) else { return nil }

        applyMultiCursorWorkflowResult(result)
        return currentSelectionsAsNSRanges()
    }

    func addAllOccurrences(from range: NSRange) -> [NSRange]? {
        guard let text = currentEditorTextStorageString(),
              let result = multiCursorWorkflowController.addAllOccurrencesResult(
                from: range,
                currentState: multiCursorState,
                text: text,
                using: multiCursorController
              ) else { return nil }

        applyMultiCursorWorkflowResult(result)
        return currentSelectionsAsNSRanges()
    }

    func removeLastOccurrenceSelection() -> [NSRange]? {
        guard let result = multiCursorWorkflowController.removeLastOccurrenceResult(
            currentState: multiCursorState,
            existingSession: multiCursorSearchSession,
            using: multiCursorController
        ) else { return nil }

        applyMultiCursorWorkflowResult(result)
        return currentSelectionsAsNSRanges()
    }

    private func applyMultiCursorWorkflowResult(
        _ result: EditorMultiCursorWorkflowResult,
        shouldLog: Bool = true
    ) {
        multiCursorSearchSession = result.session
        applyMultiCursorState(result.state)

        if let warningMessage = result.warningMessage {
            showStatusToast(warningMessage, level: .warning)
        }

        if shouldLog, let action = result.logAction {
            logMultiCursorState(action: action, note: result.logNote)
        }
    }

    func multiCursorSummaryText() -> String {
        multiCursorController.summaryText(for: multiCursorState)
    }

    func applyMultiCursorReplacement(_ replacement: String) -> [MultiCursorSelection]? {
        guard let text = documentController.buffer?.text ?? content?.string else { return nil }
        let selections = multiCursorState.all
        guard selections.count > 1 else { return nil }

        let outcome = multiCursorController.replacementResult(
            text: text,
            selections: selections,
            replacement: replacement
        )
        let result = outcome.result
        applyEditorTransaction(outcome.transaction, reason: "multi_cursor_replace")
        endMultiCursorSearchSession()
        return result.selections
    }

    func applyMultiCursorOperation(_ operation: MultiCursorOperation) -> [MultiCursorSelection]? {
        guard let text = documentController.buffer?.text ?? content?.string else { return nil }
        let selections = multiCursorState.all
        guard selections.count > 1 else { return nil }

        let outcome = multiCursorController.operationResult(
            text: text,
            selections: selections,
            operation: operation
        )
        applyEditorTransaction(outcome.transaction, reason: "multi_cursor_operation")
        return outcome.result.selections
    }

    // MARK: - Text Edit Application (Transaction-First)
    //
    // 所有文本编辑应用最终都通过 documentController 的 transaction 路径落地，
    // 然后统一进入 commitDocumentEditResult 进行后处理（selection 同步、LSP 通知、行数更新等）。

    /// 将 LSP TextEdits 应用到当前文档，走 transaction 路径。
    /// 这是 Phase 1 "format / rename / code action 走 transaction" 的核心入口。
    /// Code Action 的 WorkspaceEdit 统一入口。
    /// 当前文件的 edits 走 transaction；其他文件直接写磁盘。
    /// 这是 Phase 1 "code action text edits 走 transaction" 的落地方法。
    /// 将 TextEdits 应用到非当前文件（直接写磁盘）。
    // MARK: - Kernel Phase 1

    // MARK: - Canonical Selection (Phase 2)

    /// 内核 canonical selection set。
    /// 这是选区的最终真相来源，原生 TextView 的选区只是它的渲染镜像。
    /// 由 EditorSelectionMapper 负责双向转换。
    private(set) var canonicalSelectionSet: EditorSelectionSet = .initial

    /// 接受从原生视图转换来的 canonical selection 更新。
    /// 由 EditorCoordinator 通过 EditorSelectionMapper.toCanonical 调用。
    func applyCanonicalSelectionSet(_ selectionSet: EditorSelectionSet) {
        canonicalSelectionSet = selectionSet
        // 同步到外部 multiCursorState（向后兼容）
        let mcSelections = selectionSet.toMultiCursorSelections()
        applyMultiCursorSelections(mcSelections)
        // 选区变化后更新括号匹配
        updateBracketMatch()
    }

    /// 将内核 canonical selection 应用到原生 TextView（canonical → view 方向）。
    /// 在事务应用后、选区恢复等场景调用。
    func pushCanonicalSelectionToView() {
        guard let textView = focusedTextView else { return }
        EditorSelectionMapper.applyToView(canonicalSelectionSet, textView: textView)
    }

    private func applyEditorTransaction(_ transaction: EditorTransaction, reason: String) {
        let perfToken = EditorPerformance.shared.begin(.editTransaction)
        let before = captureUndoState()
        guard let result = documentController.apply(transaction: transaction) else {
            EditorPerformance.shared.cancel(perfToken)
            return
        }
        commitDocumentEditResult(result, reason: reason)
        recordUndoChange(from: before, reason: reason)
        EditorPerformance.shared.end(perfToken, metadata: ["reason": reason])
    }

    func applyBracketAutoClosingEdit(
        replacementRange: NSRange,
        replacementText: String,
        selectedRange: NSRange
    ) -> Bool {
        applyInputEdit(
            replacementRange: replacementRange,
            replacementText: replacementText,
            selectedRanges: [selectedRange],
            reason: "bracket_auto_closing"
        )
    }

    func applySmartIndentEdit(
        replacementRange: NSRange,
        replacementText: String,
        cursorLocation: Int
    ) -> Bool {
        applyInputEdit(
            replacementRange: replacementRange,
            replacementText: replacementText,
            selectedRanges: [NSRange(location: cursorLocation, length: 0)],
            reason: "smart_indent_enter"
        )
    }

    func applyOutdentEdit(
        replacementRange: NSRange,
        replacementText: String,
        selectedRange: NSRange
    ) -> Bool {
        applyInputEdit(
            replacementRange: replacementRange,
            replacementText: replacementText,
            selectedRanges: [selectedRange],
            reason: "smart_outdent"
        )
    }

    func applyFullTextEdit(
        replacementText: String,
        selectedRanges: [NSRange],
        reason: String
    ) -> Bool {
        let fullLength = (content?.string ?? "") as NSString
        return applyInputEdit(
            replacementRange: NSRange(location: 0, length: fullLength.length),
            replacementText: replacementText,
            selectedRanges: selectedRanges,
            reason: reason
        )
    }

    func handleTextInput(_ text: String, replacementRange: NSRange, textViewSelections: [NSRange]) -> Bool {
        if let currentText = currentEditorTextStorageString() as? String,
           let plan = textInputController.textInputPlan(
                text: text,
                replacementRange: replacementRange,
                textViewSelections: textViewSelections,
                multiCursorSelectionCount: multiCursorState.all.count,
                currentText: currentText,
                languageId: detectedLanguage?.tsName ?? "swift"
           ) {
            return applyInputEdit(
                replacementRange: plan.replacementRange,
                replacementText: plan.replacementText,
                selectedRanges: plan.selectedRanges,
                reason: plan.reason
            )
        }

        guard multiCursorState.all.count > 1 else { return false }
        return applyMultiCursorOperation(.replaceSelection(text)) != nil
    }

    func handleDeleteBackwardInput() -> Bool {
        guard multiCursorState.all.count > 1 else { return false }
        return applyMultiCursorOperation(.deleteBackward) != nil
    }

    func handleInsertNewlineInput(textViewSelections: [NSRange]) -> Bool {
        guard let currentText = currentEditorTextStorageString() as? String,
              let plan = textInputController.insertNewlinePlan(
                textViewSelections: textViewSelections,
                multiCursorSelectionCount: multiCursorState.all.count,
                currentText: currentText,
                tabSize: tabWidth,
                useSpaces: useSpaces
              ) else {
            return false
        }

        return applyInputEdit(
            replacementRange: plan.replacementRange,
            replacementText: plan.replacementText,
            selectedRanges: plan.selectedRanges,
            reason: plan.reason
        )
    }

    func handleInsertTabInput(textViewSelections: [NSRange]) -> Bool {
        if multiCursorState.all.count > 1 {
            let indentUnit = useSpaces ? String(repeating: " ", count: tabWidth) : "\t"
            return applyMultiCursorOperation(.indent(indentUnit)) != nil
        }

        guard let currentText = currentEditorTextStorageString() as? String,
              let plan = textInputController.insertTabPlan(
                textViewSelections: textViewSelections,
                multiCursorSelectionCount: multiCursorState.all.count,
                currentText: currentText,
                tabSize: tabWidth,
                useSpaces: useSpaces
              ) else {
            return false
        }

        return applyInputEdit(
            replacementRange: plan.replacementRange,
            replacementText: plan.replacementText,
            selectedRanges: plan.selectedRanges,
            reason: plan.reason
        )
    }

    func handleInsertBacktabInput(textViewSelections: [NSRange]) -> Bool {
        if multiCursorState.all.count > 1 {
            return applyMultiCursorOperation(.outdent(tabSize: tabWidth, useSpaces: useSpaces)) != nil
        }

        guard let currentText = currentEditorTextStorageString() as? String,
              let plan = textInputController.insertBacktabPlan(
                textViewSelections: textViewSelections,
                multiCursorSelectionCount: multiCursorState.all.count,
                currentText: currentText,
                tabSize: tabWidth,
                useSpaces: useSpaces
              ) else {
            return false
        }

        return applyInputEdit(
            replacementRange: plan.replacementRange,
            replacementText: plan.replacementText,
            selectedRanges: plan.selectedRanges,
            reason: plan.reason
        )
    }

    func applyCompletionEdit(
        replacementRange: NSRange,
        replacementText: String,
        additionalTextEdits: [TextEdit]?
    ) -> Bool {
        guard let text = documentController.currentText ?? content?.string,
              let transaction = transactionController.transactionForCompletionEdit(
                text: text,
                replacementRange: replacementRange,
                replacementText: replacementText,
                additionalTextEdits: additionalTextEdits
              ) else { return false }

        applyEditorTransaction(transaction, reason: "completion_apply")
        return true
    }

    // MARK: - Line Editing (Phase 9)

    /// 行编辑命令类型
    /// 执行行编辑命令
    func performLineEdit(_ kind: LineEditKind) {
        guard let text = content?.string, !text.isEmpty else { return }

        let selections = multiCursorState.all.count > 1
            ? multiCursorState.all.map { NSRange(location: $0.location, length: $0.length) }
            : focusedTextView?.selectionManager.textSelections.map(\.range)
                ?? [NSRange(location: 0, length: 0)]

        guard let lineEditResult = inputCommandController.lineEditResult(
            kind: kind,
            text: text,
            selections: selections,
            languageId: detectedLanguage?.tsName ?? "swift"
        ) else { return }

        let applied = applyInputEdit(
            replacementRange: lineEditResult.replacementRange,
            replacementText: lineEditResult.replacementText,
            selectedRanges: lineEditResult.selectedRanges,
            reason: "line_edit_\(kind)"
        )

        if applied {
            focusedTextView?.selectionManager.setSelectedRanges(currentSelectionsAsNSRanges())
        }
    }

    // MARK: - Cursor Motion

    /// 光标移动命令类型
    /// 执行光标移动命令
    func performCursorMotion(_ kind: CursorMotionKind) {
        guard let text = content?.string else { return }
        guard let textView = focusedTextView else { return }

        let currentLocation = textView.selectionManager.textSelections.first?.range.location ?? 0
        let currentRange = textView.selectionManager.textSelections.first?.range
            ?? NSRange(location: 0, length: 0)

        guard let plan = inputCommandController.cursorMotionPlan(
            kind: kind,
            text: text,
            currentLocation: currentLocation,
            currentRange: currentRange
        ) else { return }

        switch plan {
        case .selections(let ranges):
            textView.selectionManager.setSelectedRanges(ranges)
        case .transaction(let transaction):
            applyEditorTransaction(transaction, reason: cursorMotionReason(for: kind))
            textView.selectionManager.setSelectedRanges(currentSelectionsAsNSRanges())
        }
    }

    private func cursorMotionReason(for kind: CursorMotionKind) -> String {
        switch kind {
        case .deleteWordLeft:
            return "delete_word_left"
        case .deleteWordRight:
            return "delete_word_right"
        default:
            return "cursor_motion"
        }
    }

    private func applyInputEdit(
        replacementRange: NSRange,
        replacementText: String,
        selectedRanges: [NSRange],
        reason: String
    ) -> Bool {
        guard let transaction = transactionController.transactionForInputEdit(
            replacementRange: replacementRange,
            replacementText: replacementText,
            selectedRanges: selectedRanges
        ) else { return false }
        applyEditorTransaction(transaction, reason: reason)
        return true
    }

    func commitDocumentEditResult(_ result: EditorEditResult, reason: String) {
        let payload = transactionController.commitPayload(from: result)
        content = documentController.textStorage
        totalLines = payload.totalLines
        if let selectionSet = payload.canonicalSelectionSet,
           let selections = payload.multiCursorSelections {
            // Phase 2: 同时更新 canonical selection set 和外部 multiCursorState
            canonicalSelectionSet = selectionSet
            setSelections(selections)
        }
        lspCoordinator.replaceDocument(payload.text, version: payload.version)
        notifyContentChangedAfterSynchronizedEdit(using: payload.text)

        if Self.verbose {
            logger.info("\(Self.t)应用编辑事务: reason=\(reason), version=\(payload.version), length=\(payload.text.count)")
        }
    }

    private var currentDocumentVersion: Int {
        documentController.buffer?.version ?? 0
    }

    private func applyUndoState(_ state: EditorUndoState) {
        isRestoringUndoState = true
        defer { isRestoringUndoState = false }

        let result = documentController.replaceText(state.text)
        let payload = transactionController.commitPayload(from: result)
        content = documentController.textStorage
        totalLines = payload.totalLines
        canonicalSelectionSet = EditorSelectionSet(selections: state.selections)
        setSelections(canonicalSelectionSet.toMultiCursorSelections())
        pushCanonicalSelectionToView()
        lspCoordinator.replaceDocument(payload.text, version: payload.version)
        notifyContentChangedAfterSynchronizedEdit(using: payload.text)
    }

    func resetUndoHistory() {
        let availability = undoController.reset(in: editorUndoManager)
        canUndo = availability.canUndo
        canRedo = availability.canRedo
    }

    func syncActiveSessionState(
        scrollStateOverride: EditorScrollState? = nil
    ) {
        guard !sessionSyncGate.isSuspended else { return }

        let bridgeState = currentBridgeState()
        let scrollState = scrollStateOverride ?? focusedTextView.map { textView in
            EditorScrollState(viewportOrigin: textView.visibleRect.origin)
        } ?? activeSession.scrollState

        sessionController.syncActiveSessionState(
            activeSession: activeSession,
            fileURL: currentFileURL,
            multiCursorState: multiCursorState,
            panelState: panelController.sessionState,
            isDirty: hasUnsavedChanges,
            bridgeState: bridgeState,
            scrollState: scrollState,
            onChanged: onActiveSessionChanged
        )
    }

    func withoutSessionSync(_ body: () -> Void) {
        sessionSyncGate.withSuspended(body)
    }

    private func applyFindReplaceState(_ state: EditorFindReplaceState) {
        EditorFindReplaceStateController.apply(state, to: &editorState)
    }

    private func applyBridgeState(_ state: EditorBridgeState) {
        if let findReplaceState = sessionController.applyBridgeState(
            state,
            to: &editorState,
            cursorLine: &cursorLine,
            cursorColumn: &cursorColumn
        ) {
            applyFindReplaceState(findReplaceState)
        }
    }

    private func syncPublishedPanelDataFromPanelState() {
        isOpenEditorsPanelPresented = panelState.isOpenEditorsPanelPresented
        problemDiagnostics = panelState.problemDiagnostics
        semanticProblems = panelState.semanticProblems
        selectedProblemDiagnostic = panelState.selectedProblemDiagnostic
        isProblemsPanelPresented = panelState.isProblemsPanelPresented
        referenceResults = panelState.referenceResults.map(Self.referenceResult(from:))
        isReferencePanelPresented = panelState.isReferencePanelPresented
        isWorkspaceSymbolSearchPresented = panelState.isWorkspaceSymbolSearchPresented
        isCallHierarchyPresented = panelState.isCallHierarchyPresented
        hoverText = panelState.mouseHoverContent
        mouseHoverContent = panelState.mouseHoverContent
        mouseHoverSymbolRect = panelState.mouseHoverSymbolRect
        mouseHoverPoint = mouseHoverSymbolRect == .zero
            ? .zero
            : CGPoint(x: mouseHoverSymbolRect.midX, y: mouseHoverSymbolRect.midY)
        mouseHoverLine = 0
        mouseHoverCharacter = 0
    }

    private static func editorReferenceResult(from result: ReferenceResult) -> EditorReferenceResult {
        EditorReferenceResult(
            url: result.url,
            line: result.line,
            column: result.column,
            path: result.path,
            preview: result.preview
        )
    }

    private static func referenceResult(from result: EditorReferenceResult) -> ReferenceResult {
        ReferenceResult(
            url: result.url,
            line: result.line,
            column: result.column,
            path: result.path,
            preview: result.preview
        )
    }

    private func currentBridgeState() -> EditorBridgeState {
        sessionController.currentBridgeState(
            from: editorState,
            cursorLine: cursorLine,
            cursorColumn: cursorColumn,
            currentFindReplaceState: activeSession.findReplaceState
        )
    }

    private func currentLegacyCommandContext() -> EditorCommandContext {
        let line = max(cursorLine - 1, 0)
        let character = max(cursorColumn - 1, 0)
        let hasSelection = focusedTextView?.selectionManager.textSelections.contains(where: { !$0.range.isEmpty }) ?? false
        return EditorCommandContext(
            languageId: detectedLanguage?.tsName ?? "swift",
            hasSelection: hasSelection,
            line: line,
            character: character
        )
    }

    private func currentCommandContext() -> CommandContext {
        CommandRouter.commandContext(
            state: self,
            legacyContext: currentLegacyCommandContext()
        )
    }

    private func legacyEditorCommandSuggestions() -> [EditorCommandSuggestion] {
        editorExtensions.commandSuggestions(
            for: currentLegacyCommandContext(),
            state: self,
            textView: focusedTextView
        )
    }

    private func applyFindMatchesResult(_ result: EditorFindMatchesResult) {
        findMatches = result.matches

        var state = activeSession.findReplaceState
        findController.applyMatchesResult(result, to: &state)
        applyFindReplaceState(state)
        activeSession.findReplaceState = state
    }

    private func selectFindMatch(at index: Int) {
        guard findMatches.indices.contains(index),
              let text = content?.string else { return }

        let match = findMatches[index]
        let selection = MultiCursorSelection(location: match.range.location, length: match.range.length)
        applyMultiCursorSelections([selection])

        let cursorPositions = multiCursorController.cursorPositions(
            from: [selection],
            text: text,
            fallbackLine: max(cursorLine, 1),
            fallbackColumn: max(cursorColumn, 1),
            positionResolver: editorPosition(utf16Offset:in:)
        )
        navigateToCursorPositions(cursorPositions)

        var state = activeSession.findReplaceState
        findController.applySelectedMatch(index: index, match: match, to: &state)
        applyFindReplaceState(state)
        syncActiveSessionState()
    }

    private func multiCursorCursorPositions(from selections: [MultiCursorSelection]) -> [CursorPosition] {
        guard let text = content?.string else { return [] }
        return multiCursorController.cursorPositions(
            from: selections,
            text: text,
            fallbackLine: max(cursorLine, 1),
            fallbackColumn: max(cursorColumn, 1),
            positionResolver: editorPosition(utf16Offset:in:)
        )
    }

    private func editorPosition(utf16Offset: Int, in text: String) -> Position? {
        guard utf16Offset >= 0, utf16Offset <= text.utf16.count else { return nil }

        var consumed = 0
        var line = 0
        var character = 0

        for unit in text.utf16 {
            if consumed == utf16Offset {
                break
            }
            if unit == 0x0A {
                line += 1
                character = 0
            } else {
                character += 1
            }
            consumed += 1
        }

        return Position(line: line, character: character)
    }

    private func endMultiCursorSearchSession() {
        multiCursorSearchSession = multiCursorController.clearSession()
    }

    private func currentEditorTextStorageString() -> NSString? {
        guard let content else { return nil }
        return content.string as NSString
    }

    private func currentSelectedPlainText() -> String? {
        guard let text = content?.string,
              let selection = multiCursorState.all.first,
              selection.length > 0 else {
            return nil
        }

        let nsText = text as NSString
        let clampedLocation = max(0, min(selection.location, nsText.length))
        let clampedLength = max(0, min(selection.length, nsText.length - clampedLocation))
        guard clampedLength > 0 else { return nil }
        return nsText.substring(with: NSRange(location: clampedLocation, length: clampedLength))
    }
}
