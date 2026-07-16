import Foundation
import AppKit
import Combine
import EditorKernel
import MagicAlert
import EditorSource
import EditorTextView
import EditorLanguageRuntime
import LanguageServerProtocol
import UniformTypeIdentifiers
import SuperLogKit
import os

/// 编辑器状态管理器
/// 管理当前文件的内容（NSTextStorage）、光标位置、编辑器配置等
@MainActor
public final class EditorState: ObservableObject, SuperLog {
    private final class SessionSyncGate {
        private var depth = 0

        var isSuspended: Bool { depth > 0 }

        func withSuspended(_ body: () -> Void) {
            depth += 1
            defer { depth = max(0, depth - 1) }
            body()
        }
    }

    public nonisolated static let emoji = "📝"
    nonisolated(unsafe) static var verbose: Bool = false

    let logger = Logger(subsystem: EditorHostEnvironment.current.logSubsystem, category: "editor.state")

    // MARK: - 组合子状态容器（P2.1）
    // 所有 @Published 属性通过 computed properties 桥接到子状态容器，
    // 保持向后兼容的同时实现关注点分离。

    /// UI 状态 — 字体、主题、显示选项、光标位置
    let uiState = EditorUIState()

    /// 文件状态 — 文件元数据、内容、语言检测、保存状态
    let fileState = EditorFileState()

    /// 面板状态 — Problems、References、Hover、符号搜索、调用层级
    public let panelState = EditorPanelState()
    lazy var panelController = EditorPanelController(panelState: panelState)

    // MARK: - Problems

    /// 是否展示 Open Editors 面板
    @Published private(set) var isOpenEditorsPanelPresented: Bool = false
    @Published private(set) var isOutlinePanelPresented: Bool = false

    /// 当前文件的诊断列表（Problems 面板数据源）
    @Published private(set) var problemDiagnostics: [Diagnostic] = []

    /// 当前文件的项目语义问题（Problems 面板附加数据源）
    @Published public private(set) var semanticProblems: [EditorSemanticProblem] = []

    /// 是否正在重新解析项目上下文
    @Published public var isResyncingProjectContext: Bool = false

    /// 当前选中的问题，用于列表高亮与编辑器同步
    @Published private(set) var selectedProblemDiagnostic: Diagnostic?

    /// 是否展示 Problems 面板
    @Published private(set) var isProblemsPanelPresented: Bool = false
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var canRedo: Bool = false

    /// 当前激活会话（Phase 2 起逐步替代散落的会话级状态）
    @Published public private(set) var activeSession = EditorSession()
    @Published private(set) var findMatches: [EditorFindMatch] = []
    @Published private(set) var recentCommandIDs: [String] = []
    @Published private(set) var commandUsageCounts: [String: Int] = [:]
    @Published private(set) var viewportVisibleLineRange: Range<Int> = 0..<0
    @Published public private(set) var viewportRenderLineRange: Range<Int> = 0..<0
    public var windowId: UUID?
    private let runtimeModeController = EditorRuntimeModeController()
    private let commandController = EditorCommandController()
    private let quickOpenController = EditorQuickOpenController()
    let peekController = EditorPeekController()
    private let settingsQuickOpenController = EditorSettingsQuickOpenController()
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
    private var settingsCancellable: AnyCancellable?
    private var themeCancellable: AnyCancellable?
    private var projectContextCancellable: AnyCancellable?
    private var semanticProgressCancellable: AnyCancellable?
    private var panelBindings = Set<AnyCancellable>()
    private var multiCursorSearchSession: EditorMultiCursorSearchSession?
    private let sessionSyncGate = SessionSyncGate()
    private var isRestoringUndoState = false
    private let fileLoadRequestGeneration = RequestGeneration()
    let referencesRequestGeneration = RequestGeneration()
    let workspaceSearchRequestGeneration = RequestGeneration()
    private let editorUndoManager = EditorUndoManager()
    private var lastSemanticReadinessState: EditorSemanticReadinessState = .idle

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
        diagnosticsCancellable = diagnosticsProvider.diagnosticsPublisher
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

        panelState.$isOutlinePanelPresented
            .sink { [weak self] isPresented in
                self?.isOutlinePanelPresented = isPresented
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

        panelState.$selectedReferenceResult
            .sink { [weak self] result in
                self?.selectedReferenceResult = result.map(Self.referenceResult(from:))
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
    @Published public private(set) var currentFileURL: URL? {
        didSet {
            SuperEditorRuntimeContext.shared.updateCurrentDocument(
                fileURL: currentFileURL,
                content: content?.string
            )
            refreshProjectContextSnapshot()
        }
    }
    
    /// 当前文件内容（NSTextStorage，EditorSource 要求）
    @Published public var content: NSTextStorage? {
        didSet {
            SuperEditorRuntimeContext.shared.updateCurrentDocument(
                fileURL: currentFileURL,
                content: content?.string
            )
        }
    }

    /// 当前文档文本变更版本号。
    ///
    /// `content` 是可变的 `NSTextStorage`，文本变化不一定会替换对象本身。
    /// 需要一个显式版本号让 SwiftUI/插件可靠观察每次编辑。
    @Published public private(set) var contentRevision: UInt64 = 0

    /// 当前文档成功保存版本号。
    ///
    /// 保存成功并不会总是引起 `contentRevision` 变化，因此需要独立信号
    /// 让依赖“已保存”语义的视图可靠收到事件。
    @Published public private(set) var saveRevision: UInt64 = 0

    func recordSuccessfulSave() {
        saveRevision &+= 1
    }

    @Published public private(set) var isFileLoadInProgress: Bool = false
    @Published public private(set) var fileLoadErrorMessage: String?

    /// Phase 1: 文档文本控制器，逐步收拢 buffer/textStorage 同步与事务应用
    let documentController = EditorDocumentController()
    
    /// 编辑器 LSP 客户端抽象（从 registry 获取）
    public private(set) var lspClient: any SuperEditorLSPClient
    /// 已安装的编辑器插件信息（从 registry.installedPlugins 派生）
    var editorFeaturePlugins: [EditorPluginInfo] {
        // 已安装的插件均已通过 AppPluginVM 启用过滤，因此 isEnabled 恒为 true
        editorExtensions.installedPlugins.map { plugin in
            EditorPluginInfo(
                id: plugin.id,
                displayName: plugin.displayName,
                description: plugin.description,
                order: plugin.order,
                isConfigurable: plugin.isConfigurable,
                isEnabled: true
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

    /// 编辑器扩展注册中心
    public let editorExtensions: EditorExtensionRegistry
    var projectContextCapability: (any SuperEditorProjectContextCapability)? {
        editorExtensions.projectContextCapability(for: projectRootPath)
    }
    public var semanticCapability: (any SuperEditorSemanticCapability)? {
        editorExtensions.semanticCapability(for: currentFileURL?.absoluteString)
    }
    /// 后台扩展点解析器（异步聚合，去重/排序在后台线程执行）
    public let editorExtensionResolver = ExtensionResolver.shared
    
    // MARK: - New LSP Providers (协议接口)
    
    /// 签名帮助提供者
    public private(set) var signatureHelpProvider: any SuperEditorSignatureHelpProvider
    /// 内联提示提供者
    private(set) var inlayHintProvider: any SuperEditorInlayHintProvider
    /// 文档高亮提供者
    public private(set) var documentHighlightProvider: any SuperEditorDocumentHighlightProvider

    public let documentHighlightCoordinator: DocumentHighlightCoordinator
    public private(set) var documentHighlightPrewarmScheduler: DocumentHighlightPrewarmScheduler?
    /// 代码动作提供者
    private(set) var codeActionProvider: any SuperEditorCodeActionProvider
    /// 工作区符号搜索提供者
    public private(set) var workspaceSymbolProvider: any SuperEditorWorkspaceSymbolProvider
    /// 调用层级提供者
    public private(set) var callHierarchyProvider: any SuperEditorCallHierarchyProvider
    /// 当前文件文档符号提供者
    private(set) var documentSymbolProvider: any SuperEditorDocumentSymbolProvider
    /// 当前文件折叠范围提供者
    private(set) var foldingRangeProvider: any SuperEditorFoldingRangeProvider
    /// 诊断数据流提供者
    private(set) var diagnosticsProvider: any SuperEditorLSPDiagnosticsProvider
    
    /// 跳转定义代理（右键和 Cmd+Click 共享）
    public weak var jumpDelegate: EditorJumpToDefinitionDelegate?

    /// 当前获得焦点的 `TextView`（Code Action、Inlay 可见范围等）
    public weak var focusedTextView: TextView?

    private var fullLoadOverrides: Set<URL> = []

    public var isSyntaxHighlightingEnabledInViewport: Bool {
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

    public var areDocumentHighlightsEnabled: Bool {
        isSyntaxHighlightingEnabledInViewport
    }

    public var areHoversEnabled: Bool {
        isSyntaxHighlightingEnabledInViewport
    }

    public var areSignatureHelpEnabled: Bool {
        isSyntaxHighlightingEnabledInViewport
    }

    public var areCodeActionsEnabled: Bool {
        isSyntaxHighlightingEnabledInViewport
    }

    public var canLoadFullFile: Bool {
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

    func renderedSurfaceHighlights(
        textView: TextView,
        lineTable: LineOffsetTable
    ) -> [EditorSurfaceHighlight] {
        let hoverRect: CGRect? = panelState.hasActiveHover ? panelState.mouseHoverSymbolRect : nil
        return overlayController.surfaceHighlights(
            matches: currentRenderedFindMatches(lineTable: lineTable),
            selectedRange: activeSession.findReplaceState.selectedMatchRange,
            bracketMatch: renderedBracketMatch(lineTable: lineTable),
            cursorLine: cursorLine,
            isPrimaryCursorRendered: isPrimaryCursorRendered,
            textView: textView,
            lineTable: lineTable,
            theme: currentTheme,
            hoverSymbolRect: hoverRect
        )
    }

    func renderedInlayHints(_ hints: [InlayHintItem]) -> [InlayHintItem] {
        runtimeModeController.renderedInlayHints(
            hints,
            renderRange: viewportRenderLineRange
        )
    }

    func renderedGutterDecorations(
        textView: TextView,
        lineTable: LineOffsetTable
    ) -> [EditorGutterDecoration] {
        guard showGutter else { return [] }
        return overlayController.gutterDecorations(
            diagnostics: problemDiagnostics,
            selectedDiagnostic: selectedProblemDiagnostic,
            documentSymbols: documentSymbolProvider.symbols,
            extensionSuggestions: editorExtensions.gutterDecorationSuggestions(
                for: EditorGutterDecorationContext(
                    languageId: detectedLanguage?.tsName ?? "swift",
                    currentLine: cursorLine,
                    visibleLineRange: viewportVisibleLineRange,
                    renderLineRange: viewportRenderLineRange,
                    isLargeFileMode: largeFileMode != .normal
                ),
                state: self
            ),
            textView: textView,
            lineTable: lineTable,
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

    public var currentRenderedInlayHints: [InlayHintItem] {
        renderedInlayHints(inlayHintProvider.hints)
    }

    public var shouldPresentInlayHintsStrip: Bool {
        !largeFileMode.isInlayHintsDisabled && !currentRenderedInlayHints.isEmpty
    }

    var shouldPresentHoverOverlay: Bool {
        overlayController.shouldPresentHoverOverlay(
            areHoversEnabled: areHoversEnabled,
            hasActiveHover: panelState.hasActiveHover,
            hoverText: panelState.mouseHoverContent
        )
    }

    public var currentHoverOverlayText: String? {
        overlayController.hoverOverlayText(
            shouldPresent: shouldPresentHoverOverlay,
            hoverText: panelState.mouseHoverContent
        )
    }

    var currentHoverOverlayRect: CGRect {
        panelState.mouseHoverSymbolRect
    }

    public var shouldCancelHoverForViewportTransition: Bool {
        panelState.hasActiveHover
    }

    public func shouldCancelHoverForRuntimeAvailabilityChange(_ isEnabled: Bool) -> Bool {
        !isEnabled
    }

    public func hoverOverlayPlacement(
        in containerSize: CGSize,
        popoverSize: CGSize,
        style: EditorHoverOverlayStyle = .standard
    ) -> EditorHoverOverlayPlacement {
        overlayController.hoverOverlayOffset(
            symbolRect: panelState.mouseHoverSymbolRect,
            containerSize: containerSize,
            popoverSize: popoverSize,
            style: style
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

    public var currentSignatureHelpOverlayItem: SignatureHelpItem? {
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

    public var currentCodeActionOverlayActions: [CodeActionItem] {
        overlayController.codeActionOverlayActions(
            shouldPresent: shouldPresentCodeActionOverlay,
            actions: codeActionProvider.actions
        )
    }

    var selectedCodeAction: CodeActionItem? {
        let actions = codeActionProvider.actions
        guard actions.indices.contains(selectedCodeActionIndex) else { return nil }
        return actions[selectedCodeActionIndex]
    }

    public func toggleCodeActionPanel() {
        if isCodeActionPanelPresented {
            dismissCodeActionPanel()
        } else {
            _ = presentCodeActionPanel(preferPreferred: true)
        }
    }

    @discardableResult
    func presentCodeActionPanel(preferPreferred: Bool) -> Bool {
        let actions = codeActionProvider.actions
        guard !actions.isEmpty else {
            dismissCodeActionPanel()
            return false
        }
        isCodeActionPanelPresented = true
        reconcileCodeActionPanelState(preferPreferred: preferPreferred)
        return true
    }

    public func dismissCodeActionPanel() {
        isCodeActionPanelPresented = false
        selectedCodeActionIndex = 0
        selectedCodeActionIdentity = nil
    }

    public func reconcileCodeActionPanelState(preferPreferred: Bool = false) {
        let actions = codeActionProvider.actions
        guard !actions.isEmpty else {
            dismissCodeActionPanel()
            return
        }

        if let identity = selectedCodeActionIdentity,
           let retainedIndex = actions.firstIndex(where: { codeActionIdentity(for: $0) == identity }) {
            selectedCodeActionIndex = retainedIndex
            return
        }

        let fallbackIndex = preferredCodeActionIndex(in: actions) ?? 0
        if preferPreferred || !actions.indices.contains(selectedCodeActionIndex) {
            selectedCodeActionIndex = fallbackIndex
        } else {
            selectedCodeActionIndex = min(selectedCodeActionIndex, actions.count - 1)
        }
        selectedCodeActionIdentity = actions.indices.contains(selectedCodeActionIndex)
            ? codeActionIdentity(for: actions[selectedCodeActionIndex])
            : nil
    }

    public func selectCodeAction(at index: Int) {
        let actions = codeActionProvider.actions
        guard actions.indices.contains(index) else { return }
        selectedCodeActionIndex = index
        selectedCodeActionIdentity = codeActionIdentity(for: actions[index])
    }

    func moveCodeActionSelection(delta: Int) {
        let actions = codeActionProvider.actions
        guard !actions.isEmpty else { return }
        let nextIndex = min(max(selectedCodeActionIndex + delta, 0), actions.count - 1)
        selectCodeAction(at: nextIndex)
    }

    func applySelectedCodeAction() async {
        guard let action = selectedCodeAction else { return }
        await performCodeActionOverlayAction(action)
    }

    public func performCodeActionOverlayAction(_ action: CodeActionItem) async {
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
        dismissCodeActionPanel()
        codeActionProvider.clear()
    }

    var currentFindMatch: EditorFindMatch? {
        guard let selectedIndex = activeSession.findReplaceState.selectedMatchIndex,
              findMatches.indices.contains(selectedIndex) else {
            return nil
        }
        return findMatches[selectedIndex]
    }

    var currentReplacePreviewText: String? {
        guard let currentFindMatch,
              activeSession.findReplaceState.isFindPanelVisible,
              !activeSession.findReplaceState.replaceText.isEmpty else {
            return nil
        }
        return EditorFindReplaceTransactionBuilder.previewReplacementText(
            for: currentFindMatch,
            state: activeSession.findReplaceState
        )
    }

    public func inlinePresentations(
        textView: TextView,
        lineTable: LineOffsetTable,
        containerSize: CGSize
    ) -> [EditorInlinePresentation] {
        let renderedCurrentMatch: EditorFindMatch?
        if let currentFindMatch,
           intersectsRenderedRange(currentFindMatch.range, lineTable: lineTable) {
            renderedCurrentMatch = currentFindMatch
        } else {
            renderedCurrentMatch = nil
        }
        return overlayController.inlinePresentations(
            diagnostics: problemDiagnostics,
            selectedDiagnostic: selectedProblemDiagnostic,
            inlayHints: currentRenderedInlayHints,
            currentMatch: renderedCurrentMatch,
            replacementText: currentReplacePreviewText,
            cursorLine: cursorLine,
            textView: textView,
            lineTable: lineTable,
            containerSize: containerSize
        )
    }

    public func secondaryCursorHighlights(
        textView: TextView,
        lineTable: LineOffsetTable
    ) -> [EditorMultiCursorHighlight] {
        guard multiCursorState.isEnabled else { return [] }
        let renderedSelections = multiCursorState.secondary.filter { selection in
            if selection.length == 0 {
                return isRenderedOffset(selection.location, lineTable: lineTable)
            }
            return intersectsRenderedRange(
                EditorRange(location: selection.location, length: selection.length),
                lineTable: lineTable
            )
        }
        guard !renderedSelections.isEmpty else { return [] }
        return overlayController.secondaryCursorHighlights(
            selections: renderedSelections,
            textView: textView,
            visibleRect: textView.visibleRect
        )
    }

    public func codeActionIndicatorPlacement(
        textView: TextView,
        lineTable: LineOffsetTable,
        containerSize: CGSize,
        style: EditorCodeActionOverlayStyle = .standard
    ) -> EditorCodeActionIndicatorPlacement? {
        guard shouldPresentCodeActionOverlay else { return nil }
        return overlayController.codeActionIndicatorPlacement(
            cursorLine: cursorLine,
            textView: textView,
            lineTable: lineTable,
            containerSize: containerSize,
            style: style
        )
    }

    private func preferredCodeActionIndex(in actions: [CodeActionItem]) -> Int? {
        actions.firstIndex(where: \.isPreferred)
    }

    private func codeActionIdentity(for action: CodeActionItem) -> String {
        "\(action.kind)|\(action.title)"
    }

    /// 在光标稳定后刷新可见区域内的 Inlay Hints
    public func scheduleInlayHintsRefreshIfNeeded(controller: TextViewController) {
        scheduleInlayHintsRefreshIfNeeded(textView: controller.textView)
    }

    public func handleViewportRuntimeTransition() {
        runtimeModeController.handleViewportRuntimeTransition(
            isPrimaryCursorRendered: isPrimaryCursorRendered,
            documentHighlightProvider: documentHighlightProvider,
            signatureHelpProvider: signatureHelpProvider,
            codeActionProvider: codeActionProvider
        )
    }

    public func handleDocumentHighlightRuntimeAvailabilityChange(_ isEnabled: Bool) {
        runtimeModeController.handleDocumentHighlightRuntimeAvailabilityChange(
            isEnabled,
            documentHighlightProvider: documentHighlightProvider
        )
    }

    public func handleSignatureHelpRuntimeAvailabilityChange(_ isEnabled: Bool) {
        runtimeModeController.handleSignatureHelpRuntimeAvailabilityChange(
            isEnabled,
            signatureHelpProvider: signatureHelpProvider
        )
    }

    public func handleCodeActionRuntimeAvailabilityChange(_ isEnabled: Bool) {
        runtimeModeController.handleCodeActionRuntimeAvailabilityChange(
            isEnabled,
            codeActionProvider: codeActionProvider
        )
    }

    /// 在 viewport 或光标稳定后刷新可见区域内的 Inlay Hints
    public func scheduleInlayHintsRefreshIfNeeded(textView: TextView?) {
        runtimeModeController.scheduleInlayHintsRefreshIfNeeded(
            textView: textView,
            lspSupportsInlayHints: lspClient.supportsInlayHints,
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
    @Published public var isEditable: Bool = true
    
    /// 当前文件是否为截断预览
    @Published var isTruncated: Bool = false
    
    /// 当前文件是否可预览
    @Published public var canPreview: Bool = false

    /// 当前文件的大文件模式。
    @Published public private(set) var largeFileMode: LargeFileMode = .normal

    /// 当前文档检测到的最长长行信息。
    @Published private(set) var longestDetectedLine: LongestDetectedLine?

    /// 当前文件是否为 Markdown 预览模式
    @Published public var isMarkdownPreviewMode: Bool = false

    /// 当前文件是否为 Markdown 格式
    var isMarkdownFile: Bool {
        fileExtension == "md" || fileExtension == "mdx"
    }

    /// 当前文件是否为二进制/非文本文件（需要用 QuickLook 预览而非代码编辑器）
    @Published var isBinaryFile: Bool = false
    
    /// 文件扩展名
    @Published public var fileExtension: String = ""
    
    /// 文件名
    @Published var fileName: String = ""

    var isEditingProjectPBXProj: Bool {
        currentFileURL?.lastPathComponent == "project.pbxproj"
    }
    
    /// 当前项目根路径（由 EditorPanelView 设置，用于计算相对路径）
    public var projectRootPath: String? {
        didSet {
            restoreConfig()
            refreshProjectContextSnapshot()
        }
    }

    /// 当前项目上下文快照（供 UI / 语言链路读取）
    @Published public private(set) var projectContextSnapshot: EditorProjectContextSnapshot?
    
    /// 当前文件相对于项目根目录的路径（用于构建选区位置信息）
    /// 若无项目则返回文件名
    public var relativeFilePath: String {
        guard let url = currentFileURL else { return "" }
        return EditorQuickOpenFilePolicy.relativePath(for: url, projectRootPath: projectRootPath)
    }

    @MainActor
    func refreshProjectContextSnapshot() {
        guard let projectRootPath, !projectRootPath.isEmpty else {
            projectContextSnapshot = nil
            panelController.setSemanticProblems([])
            syncActiveSessionState()
            return
        }
        guard let capability = projectContextCapability,
              let snapshot = capability.makeEditorContextSnapshot(currentFileURL: currentFileURL),
              snapshot.projectPath == projectRootPath ||
                snapshot.workspacePath.hasPrefix(projectRootPath) ||
                projectRootPath.hasPrefix(snapshot.workspacePath) else {
            projectContextSnapshot = nil
            projectContextCapability?.updateLatestEditorSnapshot(nil)
            panelController.setSemanticProblems([])
            syncActiveSessionState()
            return
        }
        projectContextSnapshot = snapshot
        capability.updateLatestEditorSnapshot(snapshot)
        refreshSemanticProblems()
    }

    @MainActor
    private func refreshSemanticProblems() {
        guard let snapshot = projectContextSnapshot, snapshot.isStructuredProject else {
            panelController.setSemanticProblems([])
            syncActiveSessionState()
            return
        }
        let report = semanticCapability?.inspectCurrentFileContext(uri: currentFileURL?.absoluteString) ?? .empty
        projectContextCapability?.updateLatestEditorSnapshot(snapshot)
        panelController.setSemanticProblems(report.reasons.map(EditorSemanticProblem.init(reason:)))
        syncActiveSessionState()
    }

    var currentProjectContextStatus: EditorProjectContextStatus {
        guard projectContextSnapshot?.isStructuredProject == true else {
            return .unknown
        }
        return projectContextSnapshot?.contextStatus ?? .unknown
    }

    var currentProjectContextStatusDescription: String {
        currentProjectContextStatus.displayDescription
    }
    
    // MARK: - Editor State
    
    /// 编辑器状态（光标位置、滚动位置、查找文本等）
    @Published public var editorState = SourceEditorState()
    
    /// 当前行号
    @Published public var cursorLine: Int = 1
    
    /// 当前列号
    @Published public var cursorColumn: Int = 1

    // MARK: - Mouse Hover State

    /// 当前 LSP Hover 文本（光标移动触发，已废弃，保留兼容）
    @Published private(set) var hoverText: String?
    @Published public var currentPeekPresentation: EditorPeekPresentation?
    @Published public var currentInlineRenameState: EditorInlineRenameState?
    @Published public private(set) var isCodeActionPanelPresented: Bool = false
    @Published public private(set) var selectedCodeActionIndex: Int = 0
    private var pendingFoldingStateRestore: EditorFoldingState?
    private(set) var activeSnippetSession: EditorSnippetSession?

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
    public func setMouseHover(content: String, symbolRect: CGRect, hoverRange: LSPRange? = nil) {
        let currentContent = panelState.mouseHoverContent ?? ""
        let currentRect = panelState.mouseHoverSymbolRect
        let epsilon: CGFloat = 0.75
        let isSameContent = currentContent == content
        let isCloseRect = abs(currentRect.minX - symbolRect.minX) <= epsilon &&
            abs(currentRect.minY - symbolRect.minY) <= epsilon &&
            abs(currentRect.width - symbolRect.width) <= epsilon &&
            abs(currentRect.height - symbolRect.height) <= epsilon
        if isSameContent && isCloseRect && panelState.mouseHoverRange == hoverRange { return }

        panelController.setMouseHover(content: content, symbolRect: symbolRect, hoverRange: hoverRange)
        syncActiveSessionState()
    }

    /// 清除鼠标悬停状态
    public func clearMouseHover() {
        guard panelState.hasActiveHover else { return }
        if Self.verbose {
            logger.debug("\(Self.t)🚫 清除鼠标悬停")
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
    @Published public var multiCursorState = MultiCursorState()

    private var selectedCodeActionIdentity: String?

    /// References 结果列表（右侧面板）
    @Published private(set) var referenceResults: [ReferenceResult] = []
    @Published private(set) var selectedReferenceResult: ReferenceResult?

    /// 是否展示 References 面板
    @Published private(set) var isReferencePanelPresented: Bool = false
    /// 是否展示工作区符号搜索面板
    @Published public private(set) var isWorkspaceSymbolSearchPresented: Bool = false
    /// 是否展示调用层级面板
    @Published public private(set) var isCallHierarchyPresented: Bool = false

    /// 总行数
    @Published var totalLines: Int = 0
    
    /// 检测到的语言
    @Published public var detectedLanguage: EditorLanguageContext? {
        didSet {
            restoreConfig()
        }
    }
    
    // MARK: - Theme
    
    /// 当前主题 ID（与 SuperEditorThemeContributor.id 对应）
    @Published public var currentThemeId: String = "xcode-dark"
    
    /// 当前主题（缓存，避免每次重建）
    @Published public private(set) var currentTheme: EditorTheme?
    
    // MARK: - Configuration
    
    /// 字体大小
    @Published public var fontSize: Double = 13.0

    /// 字体名称（PostScript name），nil 表示使用系统等宽默认字体。
    /// 由外部插件负责持久化与恢复。
    @Published public var fontName: String?
    
    /// Tab 宽度
    @Published public var tabWidth: Int = 4
    
    /// 是否使用空格替代 Tab
    @Published public var useSpaces: Bool = true

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
    @Published public var wrapLines: Bool = true
    
    /// 是否显示 Minimap
    @Published public var showMinimap: Bool = true

    /// 切换 Minimap 显示偏好并写入磁盘。
    public func toggleShowMinimapPersisted() {
        showMinimap.toggle()
        persistConfig()
    }
    
    /// 是否显示行号
    @Published public var showGutter: Bool = true
    
    /// 是否显示代码折叠
    @Published public var showFoldingRibbon: Bool = true

    var minimapPolicy: EditorMinimapPolicy {
        EditorMinimapPolicy(
            userRequestedVisible: showMinimap,
            largeFileMode: largeFileMode
        )
    }

    
    // MARK: - Auto Save

    /// 是否有未保存的变更
    @Published var hasUnsavedChanges: Bool = false

    /// 保存状态
    @Published var saveState: EditorSaveState = .idle

    /// 自动保存模式（对齐 VS Code 的 files.autoSave）
    @Published var autoSaveMode: EditorAutoSaveMode = .off {
        didSet {
            guard autoSaveMode != oldValue else { return }
            autoSaveScheduler.handleModeChange(autoSaveMode)
        }
    }

    /// 自动保存延迟（秒，仅在 afterDelay 模式下生效）
    @Published var autoSaveDelay: Double = 1.0 {
        didSet {
            guard autoSaveDelay != oldValue else { return }
            autoSaveScheduler.handleDelayChange(autoSaveDelay)
        }
    }

    /// 自动保存防抖调度器
    let autoSaveScheduler = EditorAutoSaveScheduler()

    // MARK: - File Loading Constants
    
    /// 截断读取字节数（256KB）
    static let truncationReadBytes: Int = 256 * 1024
    
    // MARK: - Init
    
    init(editorExtensions: EditorExtensionRegistry) {
        self.editorExtensions = editorExtensions

        // Initialize all providers with null defaults first (required for Swift init safety)
        // 内核不直接引用任何插件的类型，所有能力均通过 Registry 获取
        self.signatureHelpProvider = NullSignatureHelpProvider()
        self.inlayHintProvider = NullInlayHintProvider()
        self.documentHighlightCoordinator = DocumentHighlightCoordinator()
        self.documentHighlightProvider = NullDocumentHighlightProvider()
        self.codeActionProvider = NullCodeActionProvider()
        self.workspaceSymbolProvider = NullWorkspaceSymbolProvider()
        self.callHierarchyProvider = NullCallHierarchyProvider()
        self.documentSymbolProvider = NullDocumentSymbolProvider()
        self.foldingRangeProvider = NullFoldingRangeProvider()
        self.diagnosticsProvider = NullDiagnosticsProvider()
        self.lspClient = NullLSPClient()

        applyExtensionProvidersFromRegistry(rebindCurrentDocument: false)
        commandController.refreshCoreCommandRegistrations(in: self)
        bindKeybindings()
        bindPanelState()
        bindDiagnostics()
        recentCommandIDs = EditorSettingsLifecycle.loadEditorRecentCommandIDs?() ?? []
        commandUsageCounts = EditorSettingsLifecycle.loadEditorCommandUsageCounts?() ?? [:]
        restoreConfig()
        observeSettingsChanges()
        observeThemeChanges()
        observeProjectContextChanges()
        autoSaveScheduler.bind(state: self)
    }

    /// 编辑器扩展安装完成后重新绑定 registry 能力（LSP client、providers 等）。
    public func refreshExtensionProviders() {
        documentHighlightCoordinator.bumpHighlightRevision()
        applyExtensionProvidersFromRegistry(rebindCurrentDocument: false)
        commandController.refreshCoreCommandRegistrations(in: self)
        observeProjectContextChanges()
        Task { @MainActor in
            await catchUpProjectContextAfterExtensionRegistration()
            syncCurrentDocumentWithLSPClientIfNeeded()
        }
        NotificationCenter.default.post(
            name: EditorHostEnvironment.current.notifications.editorExtensionProvidersDidChange,
            object: self
        )
    }

    /// Replays project-context side effects missed before Swift plugin reconfigured notifications.
    private func catchUpProjectContextAfterExtensionRegistration() async {
        refreshProjectContextSnapshot()
        await refreshLSPAfterProjectContextChangeIfNeeded()
    }

    private func applyExtensionProvidersFromRegistry(rebindCurrentDocument: Bool) {
        let registry = editorExtensions

        lspClient = registry.editorLSPClient ?? NullLSPClient()
        signatureHelpProvider = registry.signatureHelpProvider ?? NullSignatureHelpProvider()
        inlayHintProvider = registry.inlayHintProvider ?? NullInlayHintProvider()
        documentHighlightProvider = registry.documentHighlightProvider ?? NullDocumentHighlightProvider()
        codeActionProvider = registry.codeActionProvider ?? NullCodeActionProvider()
        workspaceSymbolProvider = registry.workspaceSymbolProvider ?? NullWorkspaceSymbolProvider()
        callHierarchyProvider = registry.callHierarchyProvider ?? NullCallHierarchyProvider()
        documentSymbolProvider = registry.documentSymbolProvider ?? NullDocumentSymbolProvider()
        foldingRangeProvider = registry.foldingRangeProvider ?? NullFoldingRangeProvider()
        diagnosticsProvider = registry.diagnosticsProvider ?? NullDiagnosticsProvider()
        bindDiagnostics()
        jumpDelegate?.lspClient = lspClient
        jumpDelegate?.lspClientProvider = { [weak self] in
            self?.lspClient
        }

        guard rebindCurrentDocument else { return }
        syncCurrentDocumentWithLSPClientIfNeeded()
    }

    private func syncCurrentDocumentWithLSPClientIfNeeded() {
        guard let loadingURL = currentFileURL,
              let content = content?.string
        else {
            return
        }

        let languageId = detectedLanguage?.lspLanguageId ?? detectedLanguage?.languageId ?? lspActionController.languageID(for: fileExtension)
        guard let languageId else { return }

        let rootPath = projectRootPath ?? loadingURL.deletingLastPathComponent().path
        lspClient.setProjectRootPath(rootPath)
        let documentVersion = currentDocumentVersion
        Task {
            await lspClient.openFile(
                uri: loadingURL.absoluteString,
                languageId: languageId,
                content: content,
                version: documentVersion
            )
        }
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

    private func observeProjectContextChanges() {
        projectContextCancellable?.cancel()
        let notificationNames = Array(
            Set([
                EditorHostEnvironment.current.notifications.projectContextDidChange,
                Notification.Name("lumiEditorProjectContextDidChange"),
                Notification.Name("EditorProjectContextDidChange"),
            ])
        )
        projectContextCancellable = Publishers.MergeMany(
            notificationNames.map { NotificationCenter.default.publisher(for: $0) }
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            Task { @MainActor in
                await self?.handleProjectContextDidChangeForTesting()
            }
        }
    }

    func handleProjectContextDidChangeForTesting() async {
        refreshProjectContextSnapshot()
        updateSemanticReadinessFeedback()
        await refreshLSPAfterProjectContextChangeIfNeeded()
    }

    private func refreshLSPAfterProjectContextChangeIfNeeded() async {
        guard EditorProjectContextLSPRefreshPolicy.shouldRefreshOpenDocument(
            isStructuredProject: projectContextSnapshot?.isStructuredProject == true,
            contextStatus: currentProjectContextStatus,
            hasOpenFile: currentFileURL != nil
        ) else {
            return
        }

        await lspClient.refreshOpenDocumentForUpdatedProjectContext()
    }

    private func observeSettingsChanges() {
        settingsCancellable?.cancel()
        settingsCancellable = NotificationCenter.default
            .publisher(for: EditorHostEnvironment.current.notifications.settingsDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.restoreConfig()
            }
    }

    func setEditorFeaturePluginEnabled(_ pluginID: String, enabled: Bool) {
        EditorSettingsLifecycle.setEditorFeaturePluginEnabled?(pluginID, enabled)
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

    public func editorCommandPresentationModel(matching query: String = "") -> EditorCommandPresentationModel {
        editorCommandPresentationModel(from: editorCommandSuggestions(), matching: query)
    }

    public func editorCommandPresentationModel(
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
        for invocationContext: EditorCommandInvocationContext,
        matching query: String = "",
        categories: Set<EditorCommandCategory>? = nil
    ) -> EditorCommandPresentationModel {
        refreshCoreCommandRegistrations()
        return commandController.presentationModel(
            from: commandController.commandSuggestions(
                state: self,
                registryContext: invocationContext.registryContext,
                legacyContext: invocationContext.legacyContext,
                textView: invocationContext.textView
            ),
            recentCommandIDs: recentCommandIDs,
            query: query,
            categories: categories
        )
    }

    func editorContextMenuPresentationModel(
        for invocationContext: EditorCommandInvocationContext,
        matching query: String = "",
        categories: Set<EditorCommandCategory>? = nil
    ) -> EditorCommandPresentationModel {
        refreshCoreCommandRegistrations()
        let suggestions = editorExtensions.contextMenuSuggestions(
            for: invocationContext.legacyContext,
            state: self,
            textView: invocationContext.textView
        ).map(\.asCommandSuggestion)
        // 右键菜单不拆分 recent/frequent，所有命令统一放入 sections，
        // 避免执行过的命令被移出 sections 后在 injectCustomItems 中丢失。
        return commandController.presentationModel(
            from: suggestions,
            recentCommandIDs: [],
            query: query,
            categories: categories
        )
    }

    public func editorCommandPresentationModel(
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
            commandUsageCounts: commandUsageCounts,
            query: query,
            categories: categories
        )
    }

    public func performEditorCommand(id: String) {
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

    func performEditorCommand(id: String, invocationContext: EditorCommandInvocationContext) {
        refreshCoreCommandRegistrations()
        let didExecute = commandController.executeCommand(
            id: id,
            registryContext: invocationContext.registryContext,
            legacySuggestions: editorExtensions.commandSuggestions(
                for: invocationContext.legacyContext,
                state: self,
                textView: invocationContext.textView
            )
        )
        if didExecute {
            recordCommandExecution(id: id)
        }
    }

    func performEditorContextMenuCommand(id: String, invocationContext: EditorCommandInvocationContext) {
        refreshCoreCommandRegistrations()
        let suggestions = editorExtensions.contextMenuSuggestions(
            for: invocationContext.legacyContext,
            state: self,
            textView: invocationContext.textView
        ).map(\.asCommandSuggestion)
        let didExecute = commandController.executeCommand(
            id: id,
            registryContext: invocationContext.registryContext,
            legacySuggestions: suggestions
        )
        if didExecute {
            recordCommandExecution(id: id)
        }
    }

    func editorCommandInvocationContext(for textView: TextView?) -> EditorCommandInvocationContext {
        let legacyContext = makeLegacyCommandContext(for: textView)
        return EditorCommandInvocationContext(
            legacyContext: legacyContext,
            registryContext: CommandRouter.commandContext(
                from: legacyContext,
                isEditorActive: currentFileURL != nil,
                isMultiCursor: multiCursorState.isEnabled
            ),
            textView: textView
        )
    }

    func recordCommandExecution(id: String) {
        var recent = recentCommandIDs
        var counts = commandUsageCounts
        commandController.recordExecution(
            id: id,
            recentCommandIDs: &recent,
            commandUsageCounts: &counts
        )
        recentCommandIDs = recent
        commandUsageCounts = counts
        EditorSettingsLifecycle.saveEditorRecentCommandIDs?(recent)
        EditorSettingsLifecycle.saveEditorCommandUsageCounts?(counts)
    }

    func recentCommandSuggestions(matching query: String = "", limit: Int = 5) -> [EditorCommandSuggestion] {
        let normalizedLimit = max(0, limit)
        guard normalizedLimit > 0 else { return [] }
        return Array(editorCommandPresentationModel(matching: query).recentCommands.prefix(normalizedLimit))
    }

    func frequentCommandSuggestions(matching query: String = "", limit: Int = 5) -> [EditorCommandSuggestion] {
        let normalizedLimit = max(0, limit)
        guard normalizedLimit > 0 else { return [] }
        return Array(editorCommandPresentationModel(matching: query).frequentCommands.prefix(normalizedLimit))
    }

    public func preferredCommandPaletteCategory() -> EditorCommandCategory? {
        guard let rawValue = EditorSettingsLifecycle.loadEditorCommandPaletteCategory?() else { return nil }
        return EditorCommandCategory(rawValue: rawValue)
    }

    public func setPreferredCommandPaletteCategory(_ category: EditorCommandCategory?) {
        EditorSettingsLifecycle.saveEditorCommandPaletteCategory?(category?.rawValue)
    }

    func editorToolbarItems() -> [EditorToolbarItemSuggestion] {
        editorExtensions.toolbarItemSuggestions(state: self)
    }

    func editorStatusItems() -> [EditorStatusItemSuggestion] {
        editorExtensions.statusItemSuggestions(state: self)
    }

    public func quickOpenQuery(for rawQuery: String) -> EditorQuickOpenQuery {
        quickOpenController.parse(rawQuery)
    }

    public func editorQuickOpenItems(
        matching query: String,
        openEditors: [EditorOpenEditorItem],
        onOpenFile: @escaping (URL, CursorPosition?, Bool) -> Void
    ) async -> [EditorQuickOpenItemSuggestion] {
        let resolvedQuery = quickOpenQuery(for: query)

        switch resolvedQuery.scope {
        case .files:
            let fileItems = quickOpenController.fileSuggestions(
                for: resolvedQuery,
                context: EditorQuickOpenFileContext(
                    projectRootPath: projectRootPath,
                    currentFileURL: currentFileURL
                ),
                openEditors: openEditors,
                onOpenFile: onOpenFile
            )
            let settingsItems = resolvedQuery.searchText.isEmpty
                ? []
                : settingsQuickOpenController.suggestions(matching: resolvedQuery.searchText)
            let extensionItems = await editorExtensions.quickOpenSuggestions(
                matching: resolvedQuery.searchText,
                state: self
            )
            return fileItems + extensionItems + settingsItems

        case .documentSymbols:
            return quickOpenController.documentSymbolSuggestions(
                for: resolvedQuery,
                symbols: documentSymbolProvider.symbols,
                onOpenSymbol: { [weak self] symbol in
                    self?.performOpenItem(.documentSymbol(symbol))
                }
            )

        case .workspaceSymbols:
            return await editorExtensions.quickOpenSuggestions(
                matching: resolvedQuery.searchText,
                state: self
            )

        case .line:
            return quickOpenController.lineSuggestions(
                for: resolvedQuery,
                currentFileURL: currentFileURL,
                fileName: fileName,
                relativeFilePath: relativeFilePath,
                onOpenFile: onOpenFile
            )

        case .commands:
            return []
        }
    }

    // MARK: - Config Persistence
    
    /// 从持久化存储恢复配置
    private func restoreConfig() {
        let snapshot = configController.resolveConfig(
            for: EditorConfigContext(
                workspacePath: projectRootPath,
                languageId: detectedLanguage?.tsName
            )
        )
        applyConfigSnapshot(snapshot)
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
                autoSaveMode: autoSaveMode,
                autoSaveDelay: autoSaveDelay
            )
        )
    }

    private func applyConfigSnapshot(_ snapshot: EditorConfigSnapshot, skipTheme: Bool = true) {
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
        autoSaveMode = snapshot.autoSaveMode
        autoSaveDelay = snapshot.autoSaveDelay
        // 主题不在此恢复。编辑器主题由 ThemeStatusBarPlugin 通过
        // syncInitialThemeFromExternal() 和 .lumiThemeDidChange 通知统一驱动，
        // 避免旧持久化值（如 "xcode-dark"）覆盖已同步的正确主题。
    }
    
    /// 切换主题
    func setTheme(_ themeId: String) {
        applyEditorTheme(id: themeId)
        persistConfig()
    }

    /// 同步主题但不触发持久化和通知（用于 hosted state 同步）
    func syncThemeSilently(_ themeId: String) {
        guard appearanceController.syncThemeSilently(
            currentThemeId: currentThemeId,
            incomingThemeId: themeId
        ) else { return }
        applyEditorTheme(id: themeId)
    }

    /// 获取所有可用主题
    func availableThemes() -> [any SuperEditorThemeContributor] {
        editorExtensions.allThemes()
    }

    /// 应用编辑器主题。先更新 `currentTheme` 再更新 `currentThemeId`，避免 SwiftUI
    /// 在 `currentThemeId` 的 `onChange` 中读到尚未刷新的旧配色。
    private func applyEditorTheme(id themeId: String) {
        currentTheme = resolveTheme(for: themeId)
        currentThemeId = themeId
        documentHighlightCoordinator.handleThemeChange(
            textStorage: content,
            content: content?.string ?? "",
            fileURL: currentFileURL,
            language: highlightLanguageContext()
        )
    }

    /// 根据主题 ID 解析 EditorTheme
    /// 优先从插件系统获取，fallback 到 EditorThemeAdapter 默认主题
    private func resolveTheme(for id: String) -> EditorTheme {
        if let contributor = editorExtensions.theme(for: id) {
            if Self.verbose {
                logger.info("\(Self.t)✅ resolveTheme: found contributor for '\(id)'")
            }
            return contributor.createTheme()
        }
        // Fallback：插件系统未加载时使用默认 Xcode Dark 主题
        let available = editorExtensions.allThemes().map(\.id)
        if Self.verbose {
            logger.warning("\(Self.t)⚠️ resolveTheme: 找不到主题 contributor for '\(id)', available=\(available)")
        }
        return EditorThemeAdapter.fallbackTheme()
    }

    /// 监听全局主题变更通知（来自底部状态栏的主题切换）
    private func observeThemeChanges() {
        themeCancellable?.cancel()
        themeCancellable = configController.observeThemeChanges { [weak self] themeId, shouldRegisterThemeContributors in
            guard let self else { return }
            if shouldRegisterThemeContributors {
                EditorSettingsLifecycle.registerEditorThemeContributors?(self.editorExtensions)
            }
            let available = self.editorExtensions.allThemes().map(\.id)
            if Self.verbose {
                logger.info("\(Self.t)🎨 observeThemeChanges: themeId='\(themeId)', current='\(self.currentThemeId)', available=\(available)")
            }
            if self.currentThemeId == themeId {
                self.currentTheme = self.resolveTheme(for: themeId)
                return
            }
            self.applyEditorTheme(id: themeId)
        }
    }

    /// 由外层（ThemeStatusBarPlugin）在视图就绪后调用，确保编辑器使用正确的初始主题。
    ///
    /// AppThemeVM.init() 在 EditorState 之前创建，其发送的 .lumiThemeDidChange
    /// 通知在 EditorState 注册监听之前就已经发出，导致 EditorState 错过了初始通知。
    /// 此方法由 ThemeStatusBarPlugin 在视图层主动调用，将 AppThemeVM 当前主题同步到 EditorState。
    func syncInitialThemeFromExternal(_ editorThemeId: String) {
        let before = self.currentThemeId
        EditorSettingsLifecycle.registerEditorThemeContributors?(self.editorExtensions)
        if before == editorThemeId {
            currentTheme = resolveTheme(for: editorThemeId)
            if Self.verbose {
                self.logger.debug("\(Self.t)syncInitialThemeFromExternal: 刷新主题配色（\(editorThemeId)）")
            }
            return
        }
        if Self.verbose {
            self.logger.info("\(Self.t)syncInitialThemeFromExternal: \(before) → \(editorThemeId)")
        }
        applyEditorTheme(id: editorThemeId)
    }
    
    // MARK: - File Loading

    /// 活跃 session 已选中但 buffer 尚未就绪时，标记为加载中以避免 UI 误判。
    func beginPendingContentLoadIfNeeded(for url: URL) {
        guard !isContentReady(for: url) else { return }
        isFileLoadInProgress = true
        fileLoadErrorMessage = nil
    }

    private func isContentReady(for url: URL) -> Bool {
        currentFileURL == url && content != nil && canPreview
    }

    /// 加载指定文件

    func highlightLanguageContext() -> EditorLanguageContext {
        detectedLanguage
            ?? LanguageRegistry.shared.context(for: "swift")
            ?? .plainText
    }

    public func installDocumentHighlightPrewarmScheduler(sessionStore: EditorSessionStore) {
        documentHighlightPrewarmScheduler = DocumentHighlightPrewarmScheduler(
            cache: documentHighlightCoordinator.cache,
            documentStore: documentHighlightCoordinator.documentStore,
            sessionStore: sessionStore,
            stateProvider: self
        )
        documentHighlightPrewarmScheduler?.scheduleAllOpenTabs(activeFileURL: currentFileURL)
    }

    func loadFile(from url: URL?) {
        // 清理旧状态
        referencesRequestGeneration.invalidate()
        saveController.cancelSuccessClear()
        
        guard let url = url else {
            fileLoadRequestGeneration.invalidate()
            isFileLoadInProgress = false
            fileLoadErrorMessage = nil
            if Self.verbose {
                logger.info("\(self.t)loadFile: url 为 nil → resetState")
            }
            resetState()
            return
        }
        
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        if isDirectory {
            fileLoadRequestGeneration.invalidate()
            isFileLoadInProgress = false
            fileLoadErrorMessage = nil
            // xcassets 等目录类型文件：设置 currentFileURL 让预览系统处理
            let ext = url.pathExtension.lowercased()
            if ext == "xcassets" {
                if Self.verbose {
                    logger.info("\(self.t)loadFile: url 是 xcassets 目录 → 设置 currentFileURL, url=\(url.path)")
                }
                currentFileURL = url
            } else {
                if Self.verbose {
                    logger.info("\(self.t)loadFile: url 是目录 → resetState, url=\(url.path)")
                }
                resetState()
            }
            return
        }
        
        let loadingURL = url
        if let currentURL = self.currentFileURL,
           let currentContent = self.content?.string {
            self.documentHighlightCoordinator.willDeactivate(
                fileURL: currentURL,
                content: currentContent,
                language: self.highlightLanguageContext()
            )
        }
        let loadGeneration = fileLoadRequestGeneration.next()
        isFileLoadInProgress = true
        fileLoadErrorMessage = nil
        if Self.verbose {
            logger.info("\(self.t)loadFile: 开始加载 url=\(loadingURL.path), forceFullLoad=\(self.fullLoadOverrides.contains(loadingURL.standardizedFileURL))")
        }

        Task {
            do {
                let loadedDocument = try documentController.loadDocument(
                    from: url,
                    truncationReadBytes: Self.truncationReadBytes,
                    forceFullLoad: fullLoadOverrides.contains(loadingURL.standardizedFileURL)
                )

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    guard self.fileLoadRequestGeneration.isCurrent(loadGeneration) else { return }
                    let standardizedLoadingURL = loadingURL.standardizedFileURL
                    let isReloadingCurrentFile = self.currentFileURL?.standardizedFileURL == standardizedLoadingURL
                    let shouldReplaceCurrentBuffer = !isReloadingCurrentFile || self.content == nil || self.fullLoadOverrides.contains(standardizedLoadingURL)
                    guard shouldReplaceCurrentBuffer else {
                        if Self.verbose {
                                                    self.logger.info("\(self.t)loadFile: shouldReplaceCurrentBuffer=false, 跳过. url=\(loadingURL.path)")
                        }
                        self.isFileLoadInProgress = false
                        return
                    }
                    switch loadedDocument {
                    case .binary:
                        if Self.verbose {
                                                    self.logger.info("\(self.t)loadFile: → 加载二进制文件, url=\(loadingURL.path)")
                        }
                        self.loadBinaryFile(from: loadingURL, loadedDocument: loadedDocument)
                        self.isFileLoadInProgress = false
                        self.fileLoadErrorMessage = nil
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
                            self.autoSaveScheduler.cancel()

                            self.detectedLanguage = LanguageRegistry.shared.detectLanguage(
                                url: loadingURL,
                                prefixBuffer: content.getFirstLines(5),
                                suffixBuffer: content.getLastLines(5)
                            )

                            if self.detectedLanguage?.languageId == "plaintext" {
                                self.detectedLanguage = nil
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
                        self.isFileLoadInProgress = false
                        self.fileLoadErrorMessage = nil
                        self.documentHighlightCoordinator.activate(
                            fileURL: loadingURL,
                            content: content,
                            language: self.highlightLanguageContext(),
                            textStorage: self.content
                        )
                        self.documentHighlightPrewarmScheduler?.scheduleAllOpenTabs(activeFileURL: loadingURL)
                        self.syncActiveSessionState()
                        self.resetUndoHistory()
                        self.setupFileWatcher(for: loadingURL)

                        let languageId = self.detectedLanguage?.lspLanguageId ?? detectedLanguage?.languageId ?? self.lspActionController.languageID(for: self.fileExtension)
                        if let languageId {
                            let rootPath = self.projectRootPath ?? loadingURL.deletingLastPathComponent().path
                            if Self.verbose {
                                self.logger.info(
                                    "\(Self.t)LSP openFile 准备: file=\(loadingURL.path), languageId=\(languageId), projectRoot=\(self.projectRootPath ?? "<nil>"), chosenRoot=\(rootPath)"
                                )
                            }
                            self.lspClient.setProjectRootPath(rootPath)
                            let documentVersion = self.currentDocumentVersion
                            Task {
                                await self.lspClient.openFile(
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
                if Self.verbose {
                    self.logger.error("\(self.t)loadFile: 加载失败 error=\(error.localizedDescription), url=\(loadingURL.path)")
                }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    guard self.fileLoadRequestGeneration.isCurrent(loadGeneration) else { return }
                    self.isFileLoadInProgress = false
                    self.fileLoadErrorMessage = error.localizedDescription
                    self.resetState()
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
        pendingFoldingStateRestore = session.foldingState
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

    public func applySourceEditorBindingUpdate(_ update: EditorSourceEditorBindingUpdate) {
        applyInteractionUpdate(
            .sourceEditorBinding(update)
        )
    }

    func persistScrollObservation(viewportOrigin: CGPoint) {
        let scrollState = EditorScrollState(viewportOrigin: viewportOrigin)
        guard activeSession.scrollState != scrollState else { return }

        activeSession.scrollState = scrollState
        onActiveSessionChanged?(activeSession)
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
        if viewportVisibleLineRange != observation.visibleLineRange {
            viewportVisibleLineRange = observation.visibleLineRange
        }
        if viewportRenderLineRange != observation.renderLineRange {
            viewportRenderLineRange = observation.renderLineRange
        }
    }

    /// 对可见区域发起 inlay hint 请求（由 LSPViewportScheduler 调度后调用）
    private func requestInlayHintsForVisibleRange() {
        runtimeModeController.requestInlayHintsForVisibleRange(
            lspSupportsInlayHints: lspClient.supportsInlayHints,
            areInlayHintsEnabledInViewport: areInlayHintsEnabledInViewport,
            currentFileURL: currentFileURL,
            focusedTextView: focusedTextView,
            inlayHintProvider: inlayHintProvider
        )
    }

    func resetViewportObservation(totalLines: Int = 0) {
        let observation = runtimeModeController.resetViewportObservation(totalLines: totalLines)
        if viewportVisibleLineRange != observation.visibleLineRange {
            viewportVisibleLineRange = observation.visibleLineRange
        }
        if viewportRenderLineRange != observation.renderLineRange {
            viewportRenderLineRange = observation.renderLineRange
        }
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

    public func performPanelCommand(_ command: EditorPanelCommand) {
        panelController.apply(command: command)
        syncActiveSessionState()
    }

    func presentBottomPanel(_ panel: EditorBottomPanelKind?) {
        panelController.presentBottomPanel(panel)
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
    public func performNavigation(_ request: EditorNavigationRequest) {
        dismissPeek()
        dismissInlineRename()
        dismissCodeActionPanel()
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

    public func performOpenItem(_ command: EditorOpenItemCommand) {
        guard let resolved = EditorOpenItemCommandController.resolve(command) else {
            switch command {
            case .workspaceSymbol:
                showStatusToast("无法打开符号位置", level: .warning)
            case .callHierarchyItem:
                showStatusToast("无法打开调用层级目标", level: .warning)
            case .documentSymbol, .problem, .reference:
                break
            }
            return
        }

        if let diagnostic = resolved.selectedProblemDiagnostic {
            panelController.setSelectedProblemDiagnostic(diagnostic)
        }
        if let reference = resolved.selectedReferenceResult {
            panelController.setSelectedReferenceResult(reference)
        }
        if let panel = resolved.presentBottomPanel {
            presentBottomPanel(panel)
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

    func refreshDocumentOutline() {
        guard currentFileURL != nil, !isBinaryFile else {
            documentSymbolProvider.clear()
            return
        }
        documentSymbolProvider.refresh()
    }

    public func refreshFoldingRanges() {
        guard showFoldingRibbon,
              !largeFileMode.isFoldingDisabled,
              let currentFileURL,
              !isBinaryFile else {
            foldingRangeProvider.clear()
            return
        }
        Task { @MainActor [weak self] in
            await self?.foldingRangeProvider.requestRanges(uri: currentFileURL.absoluteString)
            self?.restorePersistedFoldingStateIfNeeded()
        }
    }

    func collapseCurrentFold() {
        guard let textView = focusedTextView,
              let lineTable = content.map({ LineOffsetTable(content: $0.string) }) else { return }
        if EditorFoldingController.collapseCurrent(
            cursorLine: cursorLine,
            ranges: foldingRangeProvider.ranges,
            textView: textView,
            lineTable: lineTable
        ) {
            syncActiveSessionState()
        }
    }

    func expandCurrentFold() {
        guard let textView = focusedTextView,
              let lineTable = content.map({ LineOffsetTable(content: $0.string) }) else { return }
        if EditorFoldingController.expandCurrent(
            cursorLine: cursorLine,
            ranges: foldingRangeProvider.ranges,
            textView: textView,
            lineTable: lineTable
        ) {
            syncActiveSessionState()
        }
    }

    func collapseAllFolds() {
        guard let textView = focusedTextView,
              let lineTable = content.map({ LineOffsetTable(content: $0.string) }) else { return }
        if EditorFoldingController.collapseAll(
            ranges: foldingRangeProvider.ranges,
            textView: textView,
            lineTable: lineTable
        ) {
            syncActiveSessionState()
        }
    }

    func expandAllFolds() {
        guard let textView = focusedTextView,
              let lineTable = content.map({ LineOffsetTable(content: $0.string) }) else { return }
        if EditorFoldingController.expandAll(
            ranges: foldingRangeProvider.ranges,
            textView: textView,
            lineTable: lineTable
        ) {
            syncActiveSessionState()
        }
    }

    func collapseFolds(toLevel level: Int) {
        guard let textView = focusedTextView,
              let lineTable = content.map({ LineOffsetTable(content: $0.string) }) else { return }
        if EditorFoldingController.collapseToLevel(
            level,
            ranges: foldingRangeProvider.ranges,
            textView: textView,
            lineTable: lineTable
        ) {
            syncActiveSessionState()
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
            currentPeekPresentation = nil
            currentInlineRenameState = nil
            activeSnippetSession = nil
            isCodeActionPanelPresented = false
            selectedCodeActionIndex = 0
            selectedCodeActionIdentity = nil
            saveState = .idle
            detectedLanguage = nil
            largeFileMode = .normal
            longestDetectedLine = nil
            isFileLoadInProgress = false
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
        lspClient.closeFile()
        resetUndoHistory()
        syncActiveSessionState()
    }

    func cleanupForTeardown() {
        resetState()
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
        lspClient.closeFile()
        
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
        contentRevision &+= 1
        let changed = documentController.hasChangesComparedToPersistedSnapshot(contentString)

        if changed {
            hasUnsavedChanges = true
            saveState = .editing
            lspClient.updateDocumentSnapshot(contentString)
            // 内容变化时调度防抖自动保存（仅 afterDelay 模式生效，内部有守卫）
            autoSaveScheduler.scheduleIfNeeded()
        } else {
            hasUnsavedChanges = false
            saveState = .idle
            // 内容与磁盘一致时取消待执行的自动保存
            autoSaveScheduler.cancel()
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
        lspClient.contentDidChange(range: range, text: text, version: currentDocumentVersion)
    }

    // MARK: - LSP Actions

    /// 执行文档格式化（LSP formatting）
    public func formatDocumentWithLSP() async {
        if let preflightMessage = projectLanguagePreflightMessage(operation: "格式化文档") {
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
                return await self.lspClient.requestFormatting(
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

    // MARK: - LSP Helpers
    
    // MARK: - LSP Edit Utilities

    public func clearMultiCursors() {
        applyMultiCursorWorkflowResult(
            multiCursorWorkflowController.clearedState(
                currentState: multiCursorState
            )
        )
    }

    func clearUnfocusedMultiCursorsIfNeeded() {
        guard multiCursorState.isEnabled else { return }
        guard multiCursorState.all.count <= 1 else { return }
        applyMultiCursorWorkflowResult(
            multiCursorWorkflowController.clearedState(
                currentState: multiCursorState
            ),
            shouldLog: false
        )
    }

    func setPrimarySelection(_ selection: MultiCursorSelection) {
        applyMultiCursorWorkflowResult(
            multiCursorWorkflowController.primarySelectionState(
                selection,
                currentState: multiCursorState
            )
        )
    }

    func setSelections(_ selections: [MultiCursorSelection]) {
        guard let result = multiCursorWorkflowController.setSelectionsResult(
            selections,
            existingSession: multiCursorSearchSession,
            text: currentEditorTextStorageString()
        ) else {
            clearMultiCursors()
            return
        }
        applyMultiCursorWorkflowResult(result)
    }

    public func currentSelectionsAsNSRanges() -> [NSRange] {
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
        guard Self.verbose else { return }
        let message = multiCursorController.stateLogMessage(
            action: action,
            selections: multiCursorState.all,
            note: note
        )
        logger.info("\(self.t)多光标状态 | \(message)")
    }

    public func logMultiCursorInput(action: String, textViewSelections: [NSRange], note: String? = nil) {
        guard Self.verbose else { return }
        let details = multiCursorController.inputLogMessage(
            action: action,
            textViewSelections: textViewSelections,
            note: note
        )
        logger.info("\(self.t)多光标输入 | \(details)")
        logMultiCursorState(action: "input-state-sync", note: action)
    }

    public func addNextOccurrence() {
        let range = NSRange(
            location: multiCursorState.primary.location,
            length: multiCursorState.primary.length
        )
        _ = addNextOccurrence(from: range)
    }

    @discardableResult
    public func addNextOccurrence(from range: NSRange) -> [NSRange]? {
        guard let text = currentEditorTextStorageString(),
              let result = multiCursorWorkflowController.addNextOccurrenceResult(
            from: range,
            currentState: multiCursorState,
            existingSession: multiCursorSearchSession,
            text: text
        ) else { return nil }

        applyMultiCursorWorkflowResult(result)
        return currentSelectionsAsNSRanges()
    }

    public func addAllOccurrences(from range: NSRange) -> [NSRange]? {
        guard let text = currentEditorTextStorageString(),
              let result = multiCursorWorkflowController.addAllOccurrencesResult(
                from: range,
                currentState: multiCursorState,
                text: text
              ) else { return nil }

        applyMultiCursorWorkflowResult(result)
        return currentSelectionsAsNSRanges()
    }

    public func removeLastOccurrenceSelection() -> [NSRange]? {
        guard let result = multiCursorWorkflowController.removeLastOccurrenceResult(
            currentState: multiCursorState,
            existingSession: multiCursorSearchSession
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

    public func applyMultiCursorReplacement(_ replacement: String) -> [MultiCursorSelection]? {
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

    public func handleTextInput(_ text: String, replacementRange: NSRange, textViewSelections: [NSRange]) -> Bool {
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

    public func handleDeleteBackwardInput() -> Bool {
        guard multiCursorState.all.count > 1 else { return false }
        return applyMultiCursorOperation(.deleteBackward) != nil
    }

    public func handleInsertNewlineInput(textViewSelections: [NSRange]) -> Bool {
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

    public func handleInsertTabInput(textViewSelections: [NSRange]) -> Bool {
        if advanceActiveSnippetSession(forward: true, currentSelections: textViewSelections) {
            return true
        }

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

    public func handleInsertBacktabInput(textViewSelections: [NSRange]) -> Bool {
        if advanceActiveSnippetSession(forward: false, currentSelections: textViewSelections) {
            return true
        }

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

    public func applyCompletionEdit(
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

    public func applySnippetCompletionEdit(
        replacementRange: NSRange,
        snippetText: String,
        additionalTextEdits: [TextEdit]?
    ) -> Bool {
        guard let text = documentController.currentText ?? content?.string else { return false }
        let snippet = EditorSnippetParser.parse(snippetText)
        guard let payload = transactionController.transactionForSnippetEdit(
            text: text,
            replacementRange: replacementRange,
            snippet: snippet,
            additionalTextEdits: additionalTextEdits
        ) else {
            return false
        }

        activeSnippetSession = payload.session
        applyEditorTransaction(payload.transaction, reason: "completion_apply_snippet")
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

    public func cancelActiveSnippetSession() -> Bool {
        guard let session = activeSnippetSession else { return false }
        activeSnippetSession = nil
        setSelections([MultiCursorSelection(location: session.exitSelection.location, length: session.exitSelection.length)])
        return true
    }

    private func advanceActiveSnippetSession(
        forward: Bool,
        currentSelections: [NSRange]
    ) -> Bool {
        guard var session = activeSnippetSession else { return false }

        if let currentGroup = session.currentGroup {
            let expected = currentGroup.ranges.sorted(by: rangeSort)
            let actual = currentSelections.sorted(by: rangeSort)
            if expected != actual {
                activeSnippetSession = nil
                return false
            }
        }

        let nextIndex = session.activeGroupIndex + (forward ? 1 : -1)
        if session.groups.indices.contains(nextIndex) {
            session.activeGroupIndex = nextIndex
            activeSnippetSession = session
            setSelections(
                session.groups[nextIndex].ranges.map {
                    MultiCursorSelection(location: $0.location, length: $0.length)
                }
            )
            return true
        }

        if forward {
            activeSnippetSession = nil
            setSelections([MultiCursorSelection(location: session.exitSelection.location, length: session.exitSelection.length)])
            return true
        }

        return true
    }

    private func rangeSort(_ lhs: NSRange, _ rhs: NSRange) -> Bool {
        if lhs.location != rhs.location { return lhs.location < rhs.location }
        return lhs.length < rhs.length
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
        lspClient.replaceDocument(payload.text, version: payload.version)
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
        lspClient.replaceDocument(payload.text, version: payload.version)
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
        let foldingState = currentFoldingState()

        sessionController.syncActiveSessionState(
            activeSession: activeSession,
            fileURL: currentFileURL,
            multiCursorState: multiCursorState,
            panelState: panelController.sessionState,
            isDirty: hasUnsavedChanges,
            bridgeState: bridgeState,
            scrollState: scrollState,
            foldingState: foldingState,
            onChanged: onActiveSessionChanged
        )
    }

    func withoutSessionSync(_ body: () -> Void) {
        sessionSyncGate.withSuspended(body)
    }

    private func applyFindReplaceState(_ state: EditorFindReplaceState) {
        EditorFindReplaceStateController.apply(state, to: &editorState)
    }

    private func currentFoldingState() -> EditorFoldingState {
        guard let textView = focusedTextView,
              let lineTable = content.map({ LineOffsetTable(content: $0.string) }),
              showFoldingRibbon,
              !largeFileMode.isFoldingDisabled else {
            return activeSession.foldingState
        }
        return EditorFoldingController.captureState(
            textView: textView,
            ranges: foldingRangeProvider.ranges,
            lineTable: lineTable
        )
    }

    private func restorePersistedFoldingStateIfNeeded() {
        guard let pendingFoldingStateRestore,
              !pendingFoldingStateRestore.isEmpty,
              let textView = focusedTextView,
              let lineTable = content.map({ LineOffsetTable(content: $0.string) }),
              showFoldingRibbon,
              !largeFileMode.isFoldingDisabled,
              !foldingRangeProvider.ranges.isEmpty else {
            return
        }

        let restored = EditorFoldingController.restore(
            pendingFoldingStateRestore,
            textView: textView,
            ranges: foldingRangeProvider.ranges,
            lineTable: lineTable
        )
        if restored {
            self.pendingFoldingStateRestore = nil
            syncActiveSessionState()
        }
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
        selectedReferenceResult = panelState.selectedReferenceResult.map(Self.referenceResult(from:))
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

    func openProblem(atLine line: Int) {
        guard let diagnostic = panelState.problemDiagnostics
            .filter({ Self.diagnostic($0, coversLine: line) })
            .max(by: { Self.diagnosticSeverityRank($0.severity) < Self.diagnosticSeverityRank($1.severity) }) else {
            return
        }
        performOpenItem(.problem(diagnostic))
    }

    private func updateSemanticReadinessFeedback() {
        let nextState = semanticReadinessState()
        guard nextState != lastSemanticReadinessState else { return }
        let previous = lastSemanticReadinessState
        lastSemanticReadinessState = nextState
        guard previous != .ready, nextState == .ready else { return }
        showStatusToast("Swift 语义索引已就绪", level: .success, duration: 1.6)
    }

    private func semanticReadinessState() -> EditorSemanticReadinessState {
        guard projectContextSnapshot?.isStructuredProject == true else { return .idle }
        if lspClient.hasActiveWork {
            return .indexing
        }
        switch currentProjectContextStatus {
        case .available:
            return .ready
        case .resolving:
            return .resolvingBuildContext
        case .needsResync:
            return .needsResync
        case .unavailable:
            return .unavailable
        case .unknown:
            return .idle
        }
    }

    private static func diagnostic(_ diagnostic: Diagnostic, coversLine line: Int) -> Bool {
        let startLine = Int(diagnostic.range.start.line) + 1
        let endLine = Int(diagnostic.range.end.line) + 1
        return startLine <= line && line <= endLine
    }

    private static func diagnosticSeverityRank(_ severity: DiagnosticSeverity?) -> Int {
        switch severity {
        case .error:
            return 3
        case .warning:
            return 2
        case .information:
            return 1
        default:
            return 0
        }
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
        makeLegacyCommandContext(for: focusedTextView)
    }

    private func currentCommandContext() -> CommandContext {
        CommandRouter.commandContext(
            state: self,
            legacyContext: currentLegacyCommandContext()
        )
    }

    private func makeLegacyCommandContext(for textView: TextView?) -> EditorCommandContext {
        let fallbackLine = max(cursorLine - 1, 0)
        let fallbackCharacter = max(cursorColumn - 1, 0)
        let selection = textView?.selectionManager.textSelections.first?.range
        let hasSelection = textView?.selectionManager.textSelections.contains(where: { !$0.range.isEmpty }) ?? false
        let cursorOffset = max(selection?.location ?? 0, 0)
        let position = textView.flatMap { editorPosition(utf16Offset: cursorOffset, in: $0.string) }

        return EditorCommandContext(
            languageId: detectedLanguage?.tsName ?? "swift",
            hasSelection: hasSelection,
            line: position.map { Int($0.line) } ?? fallbackLine,
            character: position.map { Int($0.character) } ?? fallbackCharacter
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

    func currentSymbolNameForRename() -> String? {
        Self.symbolNameForRename(in: content?.string ?? "", selection: multiCursorState.all.first)
    }

    static func symbolNameForRename(in text: String, selection: MultiCursorSelection?) -> String? {
        guard let selection else { return nil }

        if selection.length > 0,
           let selected = selectedPlainText(in: text, selection: selection)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !selected.isEmpty {
            return selected
        }

        guard !text.isEmpty else { return nil }

        let nsText = text as NSString
        let cursor = max(0, min(selection.location, nsText.length))
        guard let cursorIndex = String.Index(utf16Offset: cursor, in: text, clampedTo: text.startIndex...text.endIndex)
        else { return nil }

        let startIndex: String.Index
        if cursorIndex < text.endIndex, isIdentifierCharacter(text[cursorIndex]) {
            startIndex = cursorIndex
        } else if cursorIndex > text.startIndex {
            let previousIndex = text.index(before: cursorIndex)
            guard isIdentifierCharacter(text[previousIndex]) else { return nil }
            startIndex = previousIndex
        } else {
            return nil
        }

        var lowerBound = startIndex
        while lowerBound > text.startIndex {
            let previousIndex = text.index(before: lowerBound)
            guard isIdentifierCharacter(text[previousIndex]) else { break }
            lowerBound = previousIndex
        }

        var upperBound = text.index(after: startIndex)
        while upperBound < text.endIndex, isIdentifierCharacter(text[upperBound]) {
            upperBound = text.index(after: upperBound)
        }

        let symbol = text[lowerBound..<upperBound].trimmingCharacters(in: .whitespacesAndNewlines)
        return symbol.isEmpty ? nil : symbol
    }

    private static func selectedPlainText(in text: String, selection: MultiCursorSelection) -> String? {
        let nsText = text as NSString
        let clampedLocation = max(0, min(selection.location, nsText.length))
        let clampedLength = max(0, min(selection.length, nsText.length - clampedLocation))
        guard clampedLength > 0 else { return nil }
        return nsText.substring(with: NSRange(location: clampedLocation, length: clampedLength))
    }

    private static func isIdentifierCharacter(_ character: Character) -> Bool {
        let baseCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        let allowedCharacterSet = baseCharacterSet.union(.nonBaseCharacters)
        var containsBaseIdentifierScalar = false

        for scalar in character.unicodeScalars {
            if baseCharacterSet.contains(scalar) {
                containsBaseIdentifierScalar = true
            } else if !allowedCharacterSet.contains(scalar) {
                return false
            }
        }

        return containsBaseIdentifierScalar
    }

}

extension EditorState {
    /// 仅供单元测试模拟编辑器当前文件变化。
    func testing_setCurrentFileURL(_ url: URL?) {
        currentFileURL = url
    }
}

private extension String.Index {
    init?(utf16Offset: Int, in string: String, clampedTo bounds: ClosedRange<String.Index>) {
        let utf16View = string.utf16
        guard let utf16Index = utf16View.index(utf16View.startIndex, offsetBy: utf16Offset, limitedBy: utf16View.endIndex),
              let samePosition = utf16Index.samePosition(in: string) else {
            return nil
        }

        self = min(max(samePosition, bounds.lowerBound), bounds.upperBound)
    }
}

private enum EditorSemanticReadinessState: Equatable {
    case idle
    case resolvingBuildContext
    case indexing
    case needsResync
    case unavailable
    case ready
}
