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

/// LSP 引用查询结果
struct ReferenceResult: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let line: Int
    let column: Int
    let path: String
    let preview: String
}

/// 编辑器状态管理器
/// 管理当前文件的内容（NSTextStorage）、光标位置、编辑器配置等
///
/// ## 状态拆分（P2.1）
/// - `uiState` — UI 配置（字体、主题、显示选项）
/// - `fileState` — 文件元数据与内容
/// - `panelState` — 面板显示状态（problems、references、hover 等）
/// - `editorState` — 编辑器底层状态（光标、滚动、查找）
///
/// 所有 `@Published` 属性保留向后兼容，同时通过组合子状态容器实现关注点分离。
@MainActor
final class EditorState: ObservableObject, SuperLog {
    nonisolated static let emoji = "📝"
    nonisolated static let verbose = true

    private let logger = Logger(subsystem: "com.coffic.lumi", category: "editor.state")

    // MARK: - 组合子状态容器（P2.1）
    // 所有 @Published 属性通过 computed properties 桥接到子状态容器，
    // 保持向后兼容的同时实现关注点分离。

    /// UI 状态 — 字体、主题、显示选项、光标位置
    let uiState = EditorUIState()

    /// 文件状态 — 文件元数据、内容、语言检测、保存状态
    let fileState = EditorFileState()

    /// 面板状态 — Problems、References、Hover、符号搜索、调用层级
    let panelState = EditorPanelState()

    enum StatusLevel {
        case info
        case success
        case warning
        case error
    }

    // MARK: - Problems

    /// 是否展示 Open Editors 面板
    @Published private(set) var isOpenEditorsPanelPresented: Bool = false

    /// 当前文件的诊断列表（Problems 面板数据源）
    @Published private(set) var problemDiagnostics: [Diagnostic] = []

    /// 当前选中的问题，用于列表高亮与编辑器同步
    @Published private(set) var selectedProblemDiagnostic: Diagnostic?

    /// 是否展示 Problems 面板
    @Published private(set) var isProblemsPanelPresented: Bool = false

    /// 当前激活会话（Phase 2 起逐步替代散落的会话级状态）
    @Published private(set) var activeSession = EditorSession()
    @Published private(set) var findMatches: [EditorFindMatch] = []
    @Published private(set) var recentCommandIDs: [String] = []
    @Published private(set) var viewportVisibleLineRange: Range<Int> = 0..<0
    @Published private(set) var viewportRenderLineRange: Range<Int> = 0..<0
    let viewportRenderController = ViewportRenderController()
    /// LSP viewport 调度器（inlay hints、diagnostics 等）
    let lspViewportScheduler = LSPViewportScheduler()

    var onActiveSessionChanged: ((EditorSession) -> Void)?

    private var diagnosticsCancellable: AnyCancellable?
    private var panelBindings = Set<AnyCancellable>()
    private var multiCursorSearchSession: EditorMultiCursorSearchSession?
    private var isSessionSyncSuspended = false
    private let referencesRequestGeneration = RequestGeneration()

    private var savePipelineOptions: EditorSavePipelineOptions {
        EditorSavePipelineOptions(
            textParticipants: .init(
                trimTrailingWhitespace: trimTrailingWhitespaceOnSave,
                insertFinalNewline: insertFinalNewlineOnSave
            ),
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
                self?.setProblemDiagnostics(diags)
                if let selected = self?.panelState.selectedProblemDiagnostic,
                   diags.contains(where: { $0 == selected }) == false {
                    self?.setSelectedProblemDiagnostic(nil)
                }
                self?.syncActiveSessionState()
                // 面板打开时保持打开；面板关闭时不强制弹出
            }
    }

    private func bindPanelState() {
        panelBindings.removeAll()

        panelState.$problemDiagnostics
            .sink { [weak self] _ in
                self?.syncPublishedPanelDataFromPanelState()
            }
            .store(in: &panelBindings)

        panelState.$isOpenEditorsPanelPresented
            .sink { [weak self] _ in
                self?.syncPublishedPanelDataFromPanelState()
            }
            .store(in: &panelBindings)

        panelState.$selectedProblemDiagnostic
            .sink { [weak self] _ in
                self?.syncPublishedPanelDataFromPanelState()
            }
            .store(in: &panelBindings)

        panelState.$isProblemsPanelPresented
            .sink { [weak self] _ in
                self?.syncPublishedPanelDataFromPanelState()
            }
            .store(in: &panelBindings)

        panelState.$referenceResults
            .sink { [weak self] _ in
                self?.syncPublishedPanelDataFromPanelState()
            }
            .store(in: &panelBindings)

        panelState.$isReferencePanelPresented
            .sink { [weak self] _ in
                self?.syncPublishedPanelDataFromPanelState()
            }
            .store(in: &panelBindings)

        panelState.$isWorkspaceSymbolSearchPresented
            .sink { [weak self] _ in
                self?.syncPublishedPanelDataFromPanelState()
            }
            .store(in: &panelBindings)

        panelState.$isCallHierarchyPresented
            .sink { [weak self] _ in
                self?.syncPublishedPanelDataFromPanelState()
            }
            .store(in: &panelBindings)

        panelState.$mouseHoverContent
            .sink { [weak self] _ in
                self?.syncPublishedPanelDataFromPanelState()
            }
            .store(in: &panelBindings)

        panelState.$mouseHoverSymbolRect
            .sink { [weak self] _ in
                self?.syncPublishedPanelDataFromPanelState()
            }
            .store(in: &panelBindings)

        syncPublishedPanelDataFromPanelState()
    }

    // MARK: - External File Watching
    
    /// 轮询定时器
    private var pollTimer: Timer?
    
    /// 上次已知的文件修改日期
    private var lastKnownModificationDate: Date?

    private struct ExternalFileConflictState {
        let content: String
        let modificationDate: Date
    }

    private var externalFileConflictState: ExternalFileConflictState?
    
    /// 轮询间隔（秒）
    private static let pollInterval: TimeInterval = 1.0
    
    // MARK: - File State
    
    /// 当前文件 URL
    @Published private(set) var currentFileURL: URL?
    
    /// 当前文件内容（NSTextStorage，CodeEditSourceEditor 要求）
    @Published var content: NSTextStorage?

    /// Phase 1: 文档文本控制器，逐步收拢 buffer/textStorage 同步与事务应用
    private let documentController = EditorDocumentController()
    
    /// 上次持久化的内容快照（用于检测变更）
    /// 使用完整字符串存储而非 hashValue，因为 hashValue 存在哈希碰撞，
    /// 可能导致编辑后的内容被误判为"未变更"，从而跳过自动保存。
    private var persistedContentSnapshot: String?

    /// LSP 服务实例（支持依赖注入，默认仍使用共享实例）
    private let lspService: LSPService
    
    /// LSP 协调器（用于语言服务器集成）
    let lspCoordinator: LSPCoordinator
    /// 编辑器可消费的 LSP 抽象客户端（用于解耦具体实现）
    var lspClient: any EditorLSPClient { lspCoordinator }
    /// 当前编辑器链路绑定的 LSP 服务实例（供视图层注入）
    var lspServiceInstance: LSPService { lspService }
    /// 编辑器子插件管理器（负责补全/悬停/code action 等扩展点）
    let editorPluginManager: EditorPluginManager
    /// 兼容旧调用：编辑器扩展注册中心
    var editorExtensions: EditorExtensionRegistry { editorPluginManager.registry }
    /// 后台扩展点解析器（异步聚合，去重/排序在后台线程执行）
    let editorExtensionResolver = ExtensionResolver.shared
    /// 已发现的编辑器内部插件（含禁用项）
    var editorFeaturePlugins: [EditorPluginManager.PluginInfo] { editorPluginManager.discoveredPluginInfos }
    
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

    private var inlayHintRefreshTask: Task<Void, Never>?

    var isSyntaxHighlightingEnabledInViewport: Bool {
        if isLongLineProtectionSuppressingSyntaxHighlighting {
            return false
        }
        return Self.isViewportFeatureEnabled(
            viewportRange: viewportRenderLineRange,
            maxLine: largeFileMode.maxSyntaxHighlightLines
        )
    }

    var areInlayHintsEnabledInViewport: Bool {
        !largeFileMode.isInlayHintsDisabled && isSyntaxHighlightingEnabledInViewport
    }

    var isLongLineProtectionSuppressingSyntaxHighlighting: Bool {
        Self.isLongLineProtectionSuppressingSyntaxHighlighting(
            largeFileMode: largeFileMode,
            longestDetectedLine: longestDetectedLine
        )
    }

    static func isLongLineProtectionSuppressingSyntaxHighlighting(
        largeFileMode: LargeFileMode,
        longestDetectedLine: LongestDetectedLine?
    ) -> Bool {
        largeFileMode.isLongLineProtectionEnabled && longestDetectedLine != nil
    }

    static func isViewportFeatureEnabled(viewportRange: Range<Int>, maxLine: Int) -> Bool {
        if maxLine == .max {
            return true
        }
        if viewportRange.isEmpty {
            return true
        }
        return viewportRange.lowerBound < maxLine
    }

    /// 在光标稳定后刷新可见区域内的 Inlay Hints
    func scheduleInlayHintsRefreshIfNeeded(controller: TextViewController) {
        scheduleInlayHintsRefreshIfNeeded(textView: controller.textView)
    }

    /// 在 viewport 或光标稳定后刷新可见区域内的 Inlay Hints
    func scheduleInlayHintsRefreshIfNeeded(textView: TextView?) {
        inlayHintRefreshTask?.cancel()
        guard lspService.supportsInlayHints else { return }
        guard areInlayHintsEnabledInViewport else {
            inlayHintProvider.clear()
            return
        }
        guard currentFileURL != nil else { return }
        let uriSnapshot = currentFileURL?.absoluteString
        inlayHintRefreshTask = Task { @MainActor [weak self, weak textView] in
            try? await Task.sleep(for: .milliseconds(380))
            guard let self, !Task.isCancelled else { return }
            guard self.areInlayHintsEnabledInViewport else {
                self.inlayHintProvider.clear()
                return
            }
            guard let uri = uriSnapshot ?? self.currentFileURL?.absoluteString else { return }
            guard let tv = textView else { return }
            guard let range = EditorInlayHintLayout.visibleDocumentLSPRange(in: tv) else { return }
            await self.inlayHintProvider.requestHints(
                uri: uri,
                startLine: range.start.line,
                startCharacter: range.start.character,
                endLine: range.end.line,
                endCharacter: range.end.character
            )
        }
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
    var projectRootPath: String?
    
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

        panelState.setMouseHover(content: content, symbolRect: symbolRect)
        syncActiveSessionState()
    }

    /// 清除鼠标悬停状态
    func clearMouseHover() {
        guard panelState.hasActiveHover else { return }
        if Self.verbose {
            EditorPlugin.logger.debug("\(Self.t)🚫 清除鼠标悬停")
        }
        panelState.clearMouseHover()
        syncActiveSessionState()
    }

    // MARK: - Bracket Matching

    /// 当前匹配的括号对位置（UTF-16 offset）。nil 表示光标不在括号旁边。
    @Published private(set) var bracketMatchResult: BracketMatchResult?

    /// 括号匹配结果
    struct BracketMatchResult: Equatable {
        let openOffset: Int
        let closeOffset: Int

        var ranges: [NSRange] {
            [
                NSRange(location: openOffset, length: 1),
                NSRange(location: closeOffset, length: 1),
            ]
        }
    }

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

    @Published private(set) var hasExternalFileConflict: Bool = false
    
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
    @Published var saveState: SaveState = .idle
    
    /// 成功状态清除任务
    private var successClearTask: Task<Void, Never>?
    
    /// 成功状态显示时间（秒）
    static let successDisplayDuration: TimeInterval = 2.0
    
    // MARK: - File Loading Constants
    
    /// 文本探测字节数
    static let textProbeBytes = 8192
    
    /// 只读阈值（512KB）
    static let readOnlyThreshold: Int64 = 512 * 1024
    
    /// 截断阈值（2MB）
    static let truncationThreshold: Int64 = 2 * 1024 * 1024
    
    /// 截断读取字节数（256KB）
    static let truncationReadBytes: Int = 256 * 1024
    
    // MARK: - Save State Enum
    
    enum SaveState: Equatable {
        case idle
        case editing
        case saving
        case saved
        case conflict(String)
        case error(String)
        
        var icon: String {
            switch self {
            case .idle: return "checkmark.circle"
            case .editing: return "pencil.circle"
            case .saving: return "arrow.triangle.2.circlepath"
            case .saved: return "checkmark.circle.fill"
            case .conflict: return "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90"
            case .error: return "exclamationmark.triangle.fill"
            }
        }
        
        var label: String {
            switch self {
            case .idle: return String(localized: "No Changes", table: "LumiEditor")
            case .editing: return String(localized: "Editing...", table: "LumiEditor")
            case .saving: return String(localized: "Saving...", table: "LumiEditor")
            case .saved: return String(localized: "Saved", table: "LumiEditor")
            case .conflict(let msg): return msg
            case .error(let msg): return msg
            }
        }
    }
    
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
        self.editorPluginManager.autoDiscoverAndRegisterPlugins()
        self.codeActionProvider.editorExtensionRegistry = self.editorExtensions
        CoreCommandRegistrations.registerAll(in: self)
        bindPanelState()
        bindDiagnostics()
        restoreConfig()
        observeThemeChanges()
    }

    func setEditorFeaturePluginEnabled(_ pluginID: String, enabled: Bool) {
        editorPluginManager.setPluginEnabled(pluginID, enabled: enabled)
    }

    func editorCommandSuggestions() -> [EditorCommandSuggestion] {
        let legacySuggestions = legacyEditorCommandSuggestions()
        let registrySuggestions = CommandRouter.suggestionsFromRegistry(in: currentCommandContext())
        return deduplicatingCommandSuggestions(registrySuggestions + legacySuggestions)
    }

    func editorCommandSuggestions(
        for context: EditorCommandContext,
        textView: TextView?
    ) -> [EditorCommandSuggestion] {
        let legacySuggestions = editorExtensions.commandSuggestions(
            for: context,
            state: self,
            textView: textView
        )
        let registrySuggestions = CommandRouter.suggestionsFromRegistry(
            in: CommandRouter.commandContext(
                from: context,
                isEditorActive: currentFileURL != nil,
                isMultiCursor: multiCursorState.isEnabled
            )
        )
        return deduplicatingCommandSuggestions(registrySuggestions + legacySuggestions)
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
        EditorCommandPresentationModel.build(
            from: suggestions,
            recentCommandIDs: recentCommandIDs,
            query: query,
            allowedCategories: categories
        )
    }

    func performEditorCommand(id: String) {
        let didExecute = CommandRouter.execute(
            id: id,
            in: currentCommandContext(),
            legacySuggestions: legacyEditorCommandSuggestions()
        )
        if didExecute {
            recordCommandExecution(id: id)
        }
    }

    func recordCommandExecution(id: String) {
        recentCommandIDs.removeAll(where: { $0 == id })
        recentCommandIDs.insert(id, at: 0)
        if recentCommandIDs.count > 12 {
            recentCommandIDs = Array(recentCommandIDs.prefix(12))
        }
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
        if let fs = EditorConfigStore.loadDouble(forKey: EditorConfigStore.fontSizeKey) {
            fontSize = fs
        }
        if let tw = EditorConfigStore.loadInt(forKey: EditorConfigStore.tabWidthKey) {
            tabWidth = tw
        }
        if let us = EditorConfigStore.loadBool(forKey: EditorConfigStore.useSpacesKey) {
            useSpaces = us
        }
        if let format = EditorConfigStore.loadBool(forKey: EditorConfigStore.formatOnSaveKey) {
            formatOnSave = format
        }
        if let organizeImports = EditorConfigStore.loadBool(forKey: EditorConfigStore.organizeImportsOnSaveKey) {
            organizeImportsOnSave = organizeImports
        }
        if let fixAll = EditorConfigStore.loadBool(forKey: EditorConfigStore.fixAllOnSaveKey) {
            fixAllOnSave = fixAll
        }
        if let trimTrailingWhitespace = EditorConfigStore.loadBool(forKey: EditorConfigStore.trimTrailingWhitespaceOnSaveKey) {
            trimTrailingWhitespaceOnSave = trimTrailingWhitespace
        }
        if let insertFinalNewline = EditorConfigStore.loadBool(forKey: EditorConfigStore.insertFinalNewlineOnSaveKey) {
            insertFinalNewlineOnSave = insertFinalNewline
        }
        if let wl = EditorConfigStore.loadBool(forKey: EditorConfigStore.wrapLinesKey) {
            wrapLines = wl
        }
        if let sm = EditorConfigStore.loadBool(forKey: EditorConfigStore.showMinimapKey) {
            showMinimap = sm
        }
        if let sg = EditorConfigStore.loadBool(forKey: EditorConfigStore.showGutterKey) {
            showGutter = sg
        }
        if let sf = EditorConfigStore.loadBool(forKey: EditorConfigStore.showFoldingRibbonKey) {
            showFoldingRibbon = sf
        }
        if let panelWidth = EditorConfigStore.loadDouble(forKey: EditorConfigStore.sidePanelWidthKey) {
            sidePanelWidth = clampedSidePanelWidth(panelWidth)
        }
        // 恢复主题：优先读取全局主题，再兼容旧编辑器独立主题键
        if let appThemeId = ThemeManager.loadSavedThemeId() {
            currentThemeId = ThemeManager.editorThemeID(for: appThemeId)
        } else if let themeRaw = EditorConfigStore.loadString(forKey: EditorConfigStore.themeNameKey) {
            currentThemeId = themeRaw
        }
        currentTheme = resolveTheme(for: currentThemeId)
    }
    
    /// 持久化当前配置
    func persistConfig() {
        EditorConfigStore.saveValue(fontSize, forKey: EditorConfigStore.fontSizeKey)
        EditorConfigStore.saveValue(tabWidth, forKey: EditorConfigStore.tabWidthKey)
        EditorConfigStore.saveValue(useSpaces, forKey: EditorConfigStore.useSpacesKey)
        EditorConfigStore.saveValue(formatOnSave, forKey: EditorConfigStore.formatOnSaveKey)
        EditorConfigStore.saveValue(organizeImportsOnSave, forKey: EditorConfigStore.organizeImportsOnSaveKey)
        EditorConfigStore.saveValue(fixAllOnSave, forKey: EditorConfigStore.fixAllOnSaveKey)
        EditorConfigStore.saveValue(trimTrailingWhitespaceOnSave, forKey: EditorConfigStore.trimTrailingWhitespaceOnSaveKey)
        EditorConfigStore.saveValue(insertFinalNewlineOnSave, forKey: EditorConfigStore.insertFinalNewlineOnSaveKey)
        EditorConfigStore.saveValue(wrapLines, forKey: EditorConfigStore.wrapLinesKey)
        EditorConfigStore.saveValue(showMinimap, forKey: EditorConfigStore.showMinimapKey)
        EditorConfigStore.saveValue(showGutter, forKey: EditorConfigStore.showGutterKey)
        EditorConfigStore.saveValue(showFoldingRibbon, forKey: EditorConfigStore.showFoldingRibbonKey)
        EditorConfigStore.saveValue(currentThemeId, forKey: EditorConfigStore.themeNameKey)
        EditorConfigStore.saveValue(sidePanelWidth, forKey: EditorConfigStore.sidePanelWidthKey)
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
        guard currentThemeId != themeId else { return }
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
        NotificationCenter.default.addObserver(
            forName: .lumiThemeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let editorThemeId = (notification.userInfo?["editorThemeId"] as? String)
                ?? (notification.userInfo?["themeId"] as? String).map { ThemeManager.editorThemeID(for: $0) }
                ?? "xcode-dark"

            Task { @MainActor [weak self] in
                guard let self else { return }

                // 注册所有主题插件提供的编辑器 contributor
                let allContributions = PluginVM.shared.getThemeContributions()
                for contribution in allContributions {
                    if let c = contribution.editorThemeContributor as? any EditorThemeContributor {
                        self.editorExtensions.registerThemeContributor(c)
                    }
                }

                guard self.currentThemeId != editorThemeId else { return }
                self.currentThemeId = editorThemeId
                self.currentTheme = self.resolveTheme(for: editorThemeId)
            }
        }

        NotificationCenter.default.addObserver(
            forName: .lumiEditorThemeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let themeId = notification.userInfo?["themeId"] as? String else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                // 只有当外部来源的变更与当前不同时才更新，避免循环
                guard self.currentThemeId != themeId else { return }
                self.currentThemeId = themeId
                self.currentTheme = self.resolveTheme(for: themeId)
            }
        }
    }
    
    // MARK: - File Loading
    
    /// 加载指定文件
    func loadFile(from url: URL?) {
        // 清理旧状态
        referencesRequestGeneration.invalidate()
        successClearTask?.cancel()
        successClearTask = nil
        
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
                let fileSize = Int64((try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                
                guard try isLikelyTextFile(url: url) else {
                    await MainActor.run { [weak self] in
                        self?.loadBinaryFile(from: loadingURL)
                    }
                    return
                }
                
                let shouldTruncate = fileSize > Self.truncationThreshold
                let mode = LargeFileMode.mode(for: fileSize)
                
                let content: String
                if shouldTruncate {
                    content = try readTruncatedContent(from: url, maxBytes: Self.truncationReadBytes)
                } else {
                    var detectedEncoding = String.Encoding.utf8
                    content = try String(contentsOf: url, usedEncoding: &detectedEncoding)
                }
                
                await MainActor.run { [weak self] in
                    guard let self, self.currentFileURL != loadingURL || self.content == nil else { return }
                    let longestLine = LongLineDetector.findLongestLine(in: content)
                    self.withoutSessionSync {
                        self.currentFileURL = loadingURL
                        _ = self.documentController.load(text: content)
                        self.content = self.documentController.textStorage
                        self.persistedContentSnapshot = content
                        self.canPreview = true
                        self.largeFileMode = mode
                        self.longestDetectedLine = longestLine
                        self.isEditable = !shouldTruncate && !mode.isReadOnly
                        self.isTruncated = shouldTruncate
                        self.fileExtension = loadingURL.pathExtension.lowercased()
                        self.fileName = loadingURL.lastPathComponent
                        self.hasUnsavedChanges = false
                        self.saveState = .idle

                        // 检测语言
                        self.detectedLanguage = CodeLanguage.detectLanguageFrom(
                            url: loadingURL,
                            prefixBuffer: content.getFirstLines(5),
                            suffixBuffer: content.getLastLines(5)
                        )

                        // 语言 fallback：将不支持的语言映射到相近的语言
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

                        // 计算行数
                        self.totalLines = content.filter { $0 == "\n" }.count + 1
                        self.resetViewportObservation(totalLines: self.totalLines)
                        self.inlayHintProvider.clear()
                        self.codeActionProvider.clear()
                        self.inlayHintRefreshTask?.cancel()
                        self.inlayHintRefreshTask = nil
                        self.clearPanelData(
                            closeProblems: false,
                            closeReferences: false
                        )
                    }
                    self.syncActiveSessionState()
                    
                    // 启动文件变化监听器（检测外部编辑器的修改）
                    self.setupFileWatcher(for: loadingURL)
                    
                    // 初始化 LSP 集成
                    let languageId = self.detectedLanguage?.id.rawValue ?? self.languageIdForExtension(self.fileExtension)
                    if let languageId {
                        let rootPath = self.projectRootPath ?? loadingURL.deletingLastPathComponent().path
                        self.lspCoordinator.setProjectRootPath(rootPath)
                        Task {
                            await self.lspCoordinator.openFile(
                                uri: loadingURL.absoluteString,
                                languageId: languageId,
                                content: content
                            )
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

    func applySessionRestore(_ session: EditorSession) {
        let fallbackCursorPositions = multiCursorCursorPositions(from: session.multiCursorState.all)
        let restore = EditorSessionRestoreController.restoreResult(
            from: session,
            fallbackCursorPositions: fallbackCursorPositions
        )

        multiCursorState = session.multiCursorState
        restorePanelState(from: session)
        applyInteractionUpdate(.sessionRestore(restore))
        restoreScrollState(restore.scrollState)
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
        state.isFindPanelVisible = true
        applyFindReplaceObservation(state)
    }

    func closeFindPanel() {
        var state = activeSession.findReplaceState
        state.isFindPanelVisible = false
        applyFindReplaceObservation(state)
    }

    func toggleFindPanel() {
        activeSession.findReplaceState.isFindPanelVisible ? closeFindPanel() : openFindPanel()
    }

    func updateFindQuery(_ text: String) {
        var state = activeSession.findReplaceState
        state.findText = text
        state.isFindPanelVisible = true
        applyFindReplaceObservation(state)
    }

    func updateReplaceQuery(_ text: String) {
        var state = activeSession.findReplaceState
        state.replaceText = text
        state.isFindPanelVisible = true
        applyFindReplaceObservation(state)
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
        let clampedTotalLines = max(0, totalLines)
        let clampedStart = max(0, min(startLine, clampedTotalLines))
        let clampedEnd = max(clampedStart, min(endLine, clampedTotalLines))

        viewportRenderController.updateVisibleRange(
            startLine: clampedStart,
            endLine: clampedEnd,
            totalLines: clampedTotalLines
        )
        viewportVisibleLineRange = clampedStart..<clampedEnd
        viewportRenderLineRange = viewportRenderController.renderStartLine..<viewportRenderController.renderEndLine

        // 记录 viewport 变更，供 LSPViewportScheduler 判断是否变化显著
        lspViewportScheduler.recordViewport(startLine: clampedStart, endLine: clampedEnd)

        if areInlayHintsEnabledInViewport {
            // 使用 LSPViewportScheduler 做滚动节流，替代原有的 inline Task debounce
            lspViewportScheduler.scheduleInlayHints { [weak self] in
                guard let self else { return }
                self.requestInlayHintsForVisibleRange()
            }
        } else {
            inlayHintRefreshTask?.cancel()
            inlayHintProvider.clear()
        }
    }

    /// 对可见区域发起 inlay hint 请求（由 LSPViewportScheduler 调度后调用）
    private func requestInlayHintsForVisibleRange() {
        guard lspService.supportsInlayHints else { return }
        guard areInlayHintsEnabledInViewport else {
            inlayHintProvider.clear()
            return
        }
        guard let uri = currentFileURL?.absoluteString else { return }
        guard let tv = focusedTextView else { return }
        guard let range = EditorInlayHintLayout.visibleDocumentLSPRange(in: tv) else { return }
        Task { @MainActor in
            await self.inlayHintProvider.requestHints(
                uri: uri,
                startLine: range.start.line,
                startCharacter: range.start.character,
                endLine: range.end.line,
                endCharacter: range.end.character
            )
        }
    }

    func resetViewportObservation(totalLines: Int = 0) {
        viewportRenderController.updateVisibleRange(startLine: 0, endLine: 0, totalLines: max(0, totalLines))
        viewportVisibleLineRange = 0..<0
        viewportRenderLineRange = 0..<0
        lspViewportScheduler.cancelAll()
    }

    private func applyInteractionUpdate(_ update: EditorInteractionUpdate) {
        let resolved = EditorInteractionUpdateController.resolve(
            update,
            currentViewState: currentBridgeState().viewState
        )

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
        var state = activeSession.findReplaceState
        transform(&state.options)
        applyFindReplaceObservation(state)
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
        let result = EditorFindReplaceController.matches(
            in: text,
            state: currentState,
            selections: selections,
            primarySelection: selections.first
        )
        applyFindMatchesResult(result)
    }

    func selectNextFindMatch() {
        guard let nextIndex = EditorFindReplaceController.nextMatchIndex(
            in: findMatches,
            selectedMatchIndex: activeSession.findReplaceState.selectedMatchIndex
        ) else { return }
        selectFindMatch(at: nextIndex)
    }

    func selectPreviousFindMatch() {
        guard let previousIndex = EditorFindReplaceController.previousMatchIndex(
            in: findMatches,
            selectedMatchIndex: activeSession.findReplaceState.selectedMatchIndex
        ) else { return }
        selectFindMatch(at: previousIndex)
    }

    func replaceCurrentFindMatch() {
        guard let transaction = EditorFindReplaceTransactionBuilder.replaceCurrent(
            state: activeSession.findReplaceState,
            matches: findMatches
        ) else { return }
        applyEditorTransaction(transaction, reason: "find_replace_current")
        refreshFindMatches()
    }

    func replaceAllFindMatches() {
        guard let transaction = EditorFindReplaceTransactionBuilder.replaceAll(
            state: activeSession.findReplaceState,
            matches: findMatches
        ) else { return }
        applyEditorTransaction(transaction, reason: "find_replace_all")
        refreshFindMatches()
    }

    func performPanelCommand(_ command: EditorPanelCommand) {
        let updated = EditorPanelCommandController.apply(command, to: currentPanelSnapshot())
        applyPanelSnapshot(updated)
        syncActiveSessionState()
    }

    func updateSelectedProblemDiagnostic(for cursor: CursorPosition?) {
        guard let cursor else {
            setSelectedProblemDiagnostic(nil)
            return
        }

        let matchingDiagnostic = panelState.problemDiagnostics.first { diag in
            let startLine = Int(diag.range.start.line) + 1
            let endLine = Int(diag.range.end.line) + 1
            let startColumn = Int(diag.range.start.character) + 1
            let endColumn = Int(diag.range.end.character) + 1

            if cursor.start.line < startLine || cursor.start.line > endLine {
                return false
            }
            if startLine == endLine {
                let upperBound = max(endColumn, startColumn)
                return cursor.start.column >= startColumn && cursor.start.column <= upperBound
            }
            if cursor.start.line == startLine {
                return cursor.start.column >= startColumn
            }
            if cursor.start.line == endLine {
                return cursor.start.column <= max(endColumn, 1)
            }
            return true
        }

        setSelectedProblemDiagnostic(matchingDiagnostic)
    }

    func applyCursorObservation(_ positions: [CursorPosition]) {
        applyInteractionUpdate(
            .cursor(
                .observedPositions(
                    positions,
                    fallbackLine: max(cursorLine, 1),
                    fallbackColumn: max(cursorColumn, 1)
                )
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
        applyInteractionUpdate(
            .cursor(
                .explicitPositions(
                    positions,
                    fallbackLine: EditorViewState.initial.primaryCursorLine,
                    fallbackColumn: EditorViewState.initial.primaryCursorColumn
                )
            )
        )
    }

    private func updatePrimaryCursorPosition(
        line: Int,
        column: Int,
        preserveCursorSelection: Bool = true
    ) {
        applyInteractionUpdate(
            .cursor(
                .primary(
                    line: line,
                    column: column,
                    existingPositions: editorState.cursorPositions ?? [],
                    preserveCursorSelection: preserveCursorSelection
                )
            )
        )
    }

    func resetPrimaryCursorPosition() {
        editorState.cursorPositions = []
        updatePrimaryCursorPosition(
            line: EditorViewState.initial.primaryCursorLine,
            column: EditorViewState.initial.primaryCursorColumn,
            preserveCursorSelection: false
        )
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
            setSelectedProblemDiagnostic(diagnostic)
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
        withoutSessionSync {
            currentFileURL = nil
            content = nil
            documentController.clear()
            content = documentController.textStorage
            activeSession.reset()
            persistedContentSnapshot = nil
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
            clearPanelData(
                clearDiagnostics: true,
                closeProblems: false,
                closeReferences: false,
                closeWorkspaceSymbols: false,
                closeCallHierarchy: false
            )
            inlayHintProvider.clear()
            codeActionProvider.clear()
            inlayHintRefreshTask?.cancel()
            inlayHintRefreshTask = nil
            focusedTextView = nil
        }
        
        // 清理文件监听器
        cleanupFileWatcher()
        
        // 关闭 LSP 文档
        lspCoordinator.closeFile()
        syncActiveSessionState()
    }
    
    /// 加载二进制/非文本文件进行预览
    /// 不尝试解析内容，只设置文件元数据，供 QuickLook 预览使用
    func loadBinaryFile(from url: URL) {
        // 清理旧状态
        referencesRequestGeneration.invalidate()
        successClearTask?.cancel()
        successClearTask = nil
        cleanupFileWatcher()
        lspCoordinator.closeFile()
        
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        if isDirectory {
            resetState()
            return
        }
        
        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        
        withoutSessionSync {
            currentFileURL = url
            documentController.clear()
            content = documentController.textStorage
            persistedContentSnapshot = nil
            canPreview = false
            isBinaryFile = true
            isEditable = false
            isTruncated = false
            largeFileMode = LargeFileMode.mode(for: Int64(fileSize))
            longestDetectedLine = nil
            resetViewportObservation()
            fileExtension = url.pathExtension.lowercased()
            fileName = url.lastPathComponent
            hasUnsavedChanges = false
            saveState = .idle
            detectedLanguage = nil
            resetPrimaryCursorPosition()
            totalLines = 0
            clearPanelData(
                clearDiagnostics: true,
                closeProblems: false,
                closeReferences: false,
                closeWorkspaceSymbols: false,
                closeCallHierarchy: false
            )
        }
        
        // 计算文件大小显示信息
        let sizeText = ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
        if Self.verbose {
            logger.info("\(Self.t)加载二进制文件: \(url.lastPathComponent), 大小: \(sizeText)")
        }
        syncActiveSessionState()
    }
    
    // MARK: - Content Change Detection
    
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
        let changed: Bool
        if let snapshot = persistedContentSnapshot {
            // 使用精确字符串比较，而非 hashValue（存在哈希碰撞风险）
            changed = contentString != snapshot
        } else {
            // 快照为空说明尚未初始化，视为无变更
            changed = false
        }
        
        if Self.verbose {
            logger.info("\(Self.t)内容变更检测: changed=\(changed), 内容长度=\(contentString.count), 快照长度=\(self.persistedContentSnapshot?.count ?? -1), 文件=\(self.currentFileURL?.lastPathComponent ?? "nil")")
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
    
    /// 通知 LSP 发生增量文本变更（由编辑器 coordinator 转发）
    func notifyLSPIncrementalChange(range: LSPRange, text: String) {
        lspCoordinator.contentDidChange(range: range, text: text)
    }

    // MARK: - LSP Actions

    /// 执行文档格式化（LSP formatting）
    func formatDocumentWithLSP() async {
        guard canPreview, isEditable else { return }
        showStatusToast(
            String(localized: "Formatting document...", table: "LumiEditor"),
            level: .info,
            duration: 1.2
        )
        let tabSize = tabWidth
        let insertSpaces = useSpaces
        guard let edits = await lspCoordinator.requestFormatting(tabSize: tabSize, insertSpaces: insertSpaces),
              !edits.isEmpty else {
            showStatusToast(
                String(localized: "No formatting changes", table: "LumiEditor"),
                level: .warning
            )
            return
        }
        applyTextEditsToCurrentDocument(edits, reason: "lsp_format_document")
        showStatusToast(
            String(localized: "Document formatted", table: "LumiEditor"),
            level: .success
        )
    }

    /// 查询当前光标位置的引用并弹窗展示
    func showReferencesFromCurrentCursor() async {
        guard let fileURL = currentFileURL else { return }
        let requestGeneration = referencesRequestGeneration.next()
        let requestFileURL = fileURL
        showStatusToast(
            String(localized: "Finding references...", table: "LumiEditor"),
            level: .info,
            duration: 1.2
        )
        let position = currentLSPPosition()
        let references = await lspCoordinator.requestReferences(
            line: position.line,
            character: position.character
        )
        guard referencesRequestGeneration.isCurrent(requestGeneration),
              currentFileURL == requestFileURL else { return }
        guard !references.isEmpty else {
            clearPanelData(
                closeReferences: false
            )
            syncActiveSessionState()
            showStatusToast(
                String(localized: "No references found", table: "LumiEditor"),
                level: .warning
            )
            return
        }

        let items = references.compactMap { location -> ReferenceResult? in
            guard let url = URL(string: location.uri) else { return nil }
            let displayPath: String
            if url == fileURL {
                displayPath = relativeFilePath
            } else {
                displayPath = displayPathForURL(url)
            }
            let line = Int(location.range.start.line) + 1
            let column = Int(location.range.start.character) + 1
            let preview = previewLine(from: url, at: line) ?? ""
            return ReferenceResult(
                url: url,
                line: line,
                column: column,
                path: displayPath,
                preview: preview
            )
        }

        let sortedItems = items.sorted {
            if $0.path != $1.path { return $0.path < $1.path }
            if $0.line != $1.line { return $0.line < $1.line }
            return $0.column < $1.column
        }
        guard referencesRequestGeneration.isCurrent(requestGeneration),
              currentFileURL == requestFileURL else { return }
        setReferenceResults(sortedItems)
        applyPanelSnapshot(
            updatedPanelSnapshot(references: !sortedItems.isEmpty)
        )
        syncActiveSessionState()
        showStatusToast(
            String(localized: "Found references:", table: "LumiEditor") + " \(sortedItems.count)",
            level: .success
        )
    }

    func goToDefinition(for selection: NSRange) async {
        guard selection.location != NSNotFound else { return }
        showStatusToast(
            String(localized: "Finding definition...", table: "LumiEditor"),
            level: .info,
            duration: 1.2
        )
        await jumpDelegate?.performGoToDefinition(forRange: selection)
    }

    func goToDeclaration(for selection: NSRange) async {
        guard selection.location != NSNotFound else { return }
        showStatusToast(
            String(localized: "Finding declaration...", table: "LumiEditor"),
            level: .info,
            duration: 1.2
        )
        await jumpDelegate?.performGoToDeclaration(forRange: selection)
    }

    func goToTypeDefinition(for selection: NSRange) async {
        guard selection.location != NSNotFound else { return }
        showStatusToast(
            String(localized: "Finding type definition...", table: "LumiEditor"),
            level: .info,
            duration: 1.2
        )
        await jumpDelegate?.performGoToTypeDefinition(forRange: selection)
    }

    func goToImplementation(for selection: NSRange) async {
        guard selection.location != NSNotFound else { return }
        showStatusToast(
            String(localized: "Finding implementation...", table: "LumiEditor"),
            level: .info,
            duration: 1.2
        )
        await jumpDelegate?.performGoToImplementation(forRange: selection)
    }

    func updateSidePanelWidth(by delta: CGFloat) {
        sidePanelWidth = clampedSidePanelWidth(sidePanelWidth + delta)
    }

    private func clampedSidePanelWidth(_ width: Double) -> CGFloat {
        CGFloat(min(max(width, 240), 720))
    }

    func persistSidePanelWidth() {
        EditorConfigStore.saveValue(sidePanelWidth, forKey: EditorConfigStore.sidePanelWidthKey)
    }

    func showStatusToast(_ message: String, level: StatusLevel, duration: TimeInterval = 1.8) {
        let safeDuration = max(1.0, duration)
        switch level {
        case .info:
            alert_info(message, duration: safeDuration)
        case .success:
            alert_success(message, duration: safeDuration)
        case .warning:
            alert_warning(message, duration: max(safeDuration, 2.0))
        case .error:
            alert_error(message, duration: max(safeDuration, 2.0), autoDismiss: true)
        }
    }

    func openCallHierarchy() async {
        guard let fileURL = currentFileURL else { return }
        let line = max(cursorLine - 1, 0)
        let character = max(cursorColumn - 1, 0)

        await callHierarchyProvider.prepareCallHierarchy(
            uri: fileURL.absoluteString,
            line: line,
            character: character
        )

        guard callHierarchyProvider.rootItem != nil else {
            showStatusToast("未找到调用层级信息", level: .warning)
            return
        }

        performPanelCommand(.openCallHierarchy)
    }

    /// 触发重命名（先弹框输入新名称，再请求 LSP rename）
    func promptRenameSymbol() {
        guard canPreview, isEditable else { return }

        let alert = NSAlert()
        alert.messageText = String(localized: "Rename Symbol", table: "LumiEditor")
        alert.informativeText = String(localized: "Enter a new symbol name:", table: "LumiEditor")
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "Rename", table: "LumiEditor"))
        alert.addButton(withTitle: String(localized: "Cancel", table: "LumiEditor"))

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 22))
        input.placeholderString = String(localized: "New name", table: "LumiEditor")
        alert.accessoryView = input

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        let newName = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else {
            showStatusToast(
                String(localized: "Rename cancelled", table: "LumiEditor"),
                level: .warning
            )
            return
        }

        showStatusToast(
            String(localized: "Renaming symbol...", table: "LumiEditor"),
            level: .info,
            duration: 1.2
        )

        Task { @MainActor [weak self] in
            await self?.renameSymbolWithLSP(to: newName)
        }
    }

    private func renameSymbolWithLSP(to newName: String) async {
        guard let currentURI = currentFileURL?.absoluteString else { return }
        let position = currentLSPPosition()
        guard let edit = await lspCoordinator.requestRename(
            line: position.line,
            character: position.character,
            newName: newName
        ) else {
            showStatusToast(
                String(localized: "Rename failed", table: "LumiEditor"),
                level: .error
            )
            return
        }

        var changedFiles = 0
        changedFiles += applyWorkspaceEditChanges(
            edit.changes,
            documentChanges: edit.documentChanges,
            currentURI: currentURI
        )

        if changedFiles == 0 {
            showStatusToast(
                String(localized: "Rename not applied", table: "LumiEditor"),
                level: .warning
            )
            return
        }

        showStatusToast(
            String(localized: "Rename completed, updated files:", table: "LumiEditor") + " \(changedFiles)",
            level: .success
        )
    }
    
    // MARK: - Save
    
    /// 立即保存
    func saveNow() {
        if case .saving = saveState {
            return
        }
        Task { @MainActor [weak self] in
            await self?.prepareAndSaveNow()
        }
    }

    /// 仅在存在未保存改动时立即保存（用于失焦等场景）
    func saveNowIfNeeded(reason: String) {
        guard hasUnsavedChanges else { return }
        if Self.verbose {
            logger.info("\(Self.t)触发立即保存: 原因=\(reason), 文件=\(self.currentFileURL?.lastPathComponent ?? "nil")")
        }
        saveNow()
    }
    
    /// 执行保存
    private func performSave(content: String, to url: URL?) {
        guard let url else {
            if Self.verbose {
                logger.warning("\(Self.t)保存失败: url 为 nil")
            }
            return
        }
        
        if Self.verbose {
            logger.info("\(Self.t)执行保存: 路径=\(url.path), 内容长度=\(content.count)")
        }
        saveState = .saving
        
        // 使用普通 Task（继承 MainActor 隔离），文件 I/O 通过 withCheckedThrowingContinuation 移到后台线程
        // 避免 Task.detached 导致的 "sending self risks causing data races" 编译错误
        Task {
            do {
                guard FileManager.default.fileExists(atPath: url.path) else {
                    logger.error("\(Self.t)保存失败: 文件不存在 at \(url.path)")
                    saveState = .error(String(localized: "File not found", table: "LumiEditor"))
                    scheduleSuccessClear()
                    return
                }
                
                // 在后台线程执行文件写入，不阻塞 MainActor
                let contentCopy = content
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            try contentCopy.write(to: url, atomically: true, encoding: .utf8)
                            continuation.resume()
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
                
                if Self.verbose {
                    logger.info("\(Self.t)保存成功")
                }
                persistedContentSnapshot = content
                hasUnsavedChanges = false
                clearExternalFileConflict()
                saveState = .saved
                syncActiveSessionState()
                scheduleSuccessClear()
            } catch {
                logger.error("\(Self.t)保存失败: \(error)")
                saveState = .error(String(localized: "Save failed", table: "LumiEditor") + ": \(error.localizedDescription)")
                syncActiveSessionState()
                scheduleSuccessClear()
            }
        }
    }

    private func prepareSaveFormatting(_ text: String, tabSize: Int, insertSpaces: Bool) async -> String? {
        guard let edits = await lspCoordinator.requestFormatting(
            tabSize: tabSize,
            insertSpaces: insertSpaces
        ), edits.isEmpty == false else {
            return nil
        }
        return TextEditApplier.apply(edits: edits, to: text)
    }

    private func applyPreparedSaveText(_ text: String) {
        let result = documentController.replaceText(text)
        content = documentController.textStorage
        totalLines = result.snapshot.text.filter { $0 == "\n" }.count + 1
        lspCoordinator.replaceDocument(result.snapshot.text)
        notifyContentChanged()
    }

    private func fullDocumentRange(for text: String) -> LSPRange {
        let lines = text.components(separatedBy: .newlines)
        let endLine = max(lines.count - 1, 0)
        let endCharacter = lines.last?.utf16.count ?? 0
        return LSPRange(
            start: Position(line: 0, character: 0),
            end: Position(line: endLine, character: endCharacter)
        )
    }

    private func codeActionKinds(for actions: [EditorDeferredSaveAction]) -> [CodeActionKind] {
        actions.compactMap { action in
            switch action {
            case .organizeImports:
                return .SourceOrganizeImports
            case .fixAll:
                return .SourceFixAll
            }
        }
    }

    private func applyDeferredSaveActions(_ actions: [EditorDeferredSaveAction]) async {
        guard actions.isEmpty == false else { return }
        guard let currentText = documentController.currentText ?? content?.string else { return }
        let requestedKinds = codeActionKinds(for: actions)
        guard !requestedKinds.isEmpty else { return }

        let range = fullDocumentRange(for: currentText)
        let codeActions = await lspCoordinator.requestCodeAction(
            range: range,
            diagnostics: problemDiagnostics,
            triggerKinds: requestedKinds
        )
        guard !codeActions.isEmpty else { return }

        for action in codeActions {
            var resolved = action
            if resolved.edit == nil, lspService.codeActionResolveSupported,
               let resolvedAction = await lspService.resolveCodeAction(resolved) {
                resolved = resolvedAction
            }
            guard let edit = resolved.edit else { continue }
            applyCodeActionWorkspaceEdit(edit)
        }
    }

    private func prepareAndSaveNow() async {
        guard let currentContent = documentController.currentText ?? content?.string,
              let fileURL = currentFileURL else { return }

        let requestFileURL = fileURL
        let prepared = await EditorSavePipelineController.prepare(
            text: currentContent,
            options: savePipelineOptions,
            tabSize: tabWidth,
            insertSpaces: useSpaces,
            formatDocument: { [weak self] text, tabSize, insertSpaces in
                guard let self else { return nil }
                return await self.prepareSaveFormatting(
                    text,
                    tabSize: tabSize,
                    insertSpaces: insertSpaces
                )
            }
        )

        guard currentFileURL == requestFileURL else { return }

        if prepared.changed {
            applyPreparedSaveText(prepared.text)
        }

        await applyDeferredSaveActions(prepared.deferredActions)
        let finalContent = documentController.currentText ?? content?.string ?? prepared.text
        performSave(content: finalContent, to: requestFileURL)
    }
    
    /// 安排成功状态清除
    private func scheduleSuccessClear() {
        successClearTask?.cancel()
        successClearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.successDisplayDuration))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if case .saved = self?.saveState {
                    self?.saveState = .idle
                }
            }
        }
    }
    
    // MARK: - File Helpers

    // MARK: - External File Watching
    
    /// 设置文件变化监听器
    /// 使用定时轮询方案，兼容所有外部编辑器的保存方式（包括原子保存）
    private func setupFileWatcher(for url: URL) {
        cleanupFileWatcher()
        
        lastKnownModificationDate = Self.getModificationDate(of: url)
        
        // 创建定时器，每次触发时检查文件是否被外部修改
        let timer = Timer.scheduledTimer(
            withTimeInterval: Self.pollInterval,
            repeats: true
        ) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.pollFileChange(url: url)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
        
        logger.info("\(Self.t)已启动文件轮询监听：\(url.lastPathComponent)")
    }
    
    /// 停止文件监听
    private func cleanupFileWatcher() {
        pollTimer?.invalidate()
        pollTimer = nil
        lastKnownModificationDate = nil
        clearExternalFileConflict()
    }
    
    /// 轮询检查文件是否变化
    private func pollFileChange(url: URL) {
        let currentModDate = Self.getModificationDate(of: url)
        
        // 文件可能被删除
        guard let currentModDate else {
            return
        }
        
        // 修改日期没变，跳过
        if let lastDate = lastKnownModificationDate,
           currentModDate.timeIntervalSince(lastDate) < 0.5 {
            return
        }
        
        // 修改日期变了，读取内容对比
        reloadIfFileChangedExternally(url: url, currentModDate: currentModDate)
    }
    
    /// 检查文件内容是否变化并重新加载
    private func reloadIfFileChangedExternally(url: URL, currentModDate: Date) {
        guard let currentContent = content?.string else { return }
        
        Task {
            do {
                let fileHandle = try FileHandle(forReadingFrom: url)
                let data = try fileHandle.readToEnd()
                try fileHandle.close()
                
                guard let data, let newContent = String(data: data, encoding: .utf8) else { return }
                
                guard newContent != currentContent else {
                    // 内容没变，只更新修改日期
                    self.lastKnownModificationDate = currentModDate
                    return
                }
                
                if self.hasUnsavedChanges {
                    self.registerExternalFileConflict(
                        newContent,
                        modificationDate: currentModDate
                    )
                } else {
                    self.applyExternalContent(newContent, modificationDate: currentModDate)
                }
            } catch {
                if Self.verbose {
                    logger.error("\(Self.t)读取外部文件失败：\(error)")
                }
            }
        }
    }

    private func registerExternalFileConflict(_ newContent: String, modificationDate: Date) {
        if let conflict = externalFileConflictState,
           conflict.modificationDate == modificationDate,
           conflict.content == newContent {
            return
        }

        externalFileConflictState = ExternalFileConflictState(
            content: newContent,
            modificationDate: modificationDate
        )
        hasExternalFileConflict = true
        saveState = .conflict(String(localized: "File changed on disk", table: "LumiEditor"))
    }

    private func clearExternalFileConflict() {
        externalFileConflictState = nil
        hasExternalFileConflict = false
    }

    func reloadExternalFileConflict() {
        guard let conflict = externalFileConflictState else { return }
        applyExternalContent(
            conflict.content,
            modificationDate: conflict.modificationDate
        )
        clearExternalFileConflict()
    }

    func keepEditorVersionForExternalConflict() {
        guard let conflict = externalFileConflictState else { return }
        lastKnownModificationDate = conflict.modificationDate
        clearExternalFileConflict()
        saveState = hasUnsavedChanges ? .editing : .idle
    }
    
    /// 应用外部修改到编辑器
    private func applyExternalContent(_ newContent: String, modificationDate: Date) {
        if Self.verbose {
            logger.info("\(Self.t)检测到外部修改，重新加载：\(self.currentFileURL?.lastPathComponent ?? "")")
        }
        
        // 关键：原地替换现有 NSTextStorage 的内容，而不是创建新对象
        // SourceEditor 持有的是旧 NSTextStorage 的引用，替换引用不会触发 UI 更新
        let result = documentController.replaceText(newContent)
        content = documentController.textStorage
        totalLines = result.snapshot.text.filter { $0 == "\n" }.count + 1
        
        persistedContentSnapshot = newContent
        lastKnownModificationDate = modificationDate
        clearExternalFileConflict()
        hasUnsavedChanges = false
        saveState = .idle
        totalLines = newContent.filter { $0 == "\n" }.count + 1
        refreshFindMatches()
        
        // 通知 LSP 文档内容已替换
        lspCoordinator.replaceDocument(newContent)
    }
    
    /// 获取文件的修改日期
    private static func getModificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    // MARK: - File Loading
    
    /// 读取截断内容
    private func readTruncatedContent(from url: URL, maxBytes: Int) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        
        let data = try handle.read(upToCount: maxBytes) ?? Data()
        let preview = String(decoding: data, as: UTF8.self)
        let suffix = "\n\n… " + String(localized: "File too large. Preview is truncated.", table: "LumiEditor")
        return preview + suffix
    }
    
    /// 检测文件是否为文本文件
    private func isLikelyTextFile(url: URL) throws -> Bool {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        
        let sample = try handle.read(upToCount: Self.textProbeBytes) ?? Data()
        if sample.isEmpty { return true }
        
        // 包含 null 字节则不是文本文件
        if sample.contains(0) { return false }
        
        // 计算控制字符比例
        var controlByteCount = 0
        for byte in sample {
            if byte == 0x09 || byte == 0x0A || byte == 0x0D { continue }
            if byte < 0x20 { controlByteCount += 1 }
        }
        
        let ratio = Double(controlByteCount) / Double(sample.count)
        return ratio < 0.05
    }
    
    // MARK: - LSP Helpers
    
    /// 根据文件扩展名获取 LSP 语言标识
    private func languageIdForExtension(_ ext: String) -> String? {
        let mapping: [String: String] = [
            "swift": "swift",
            "py": "python",
            "js": "javascript",
            "ts": "typescript",
            "jsx": "javascript",
            "tsx": "typescript",
            "astro": "typescript",  // Astro 映射到 TypeScript
            "vue": "typescript",   // Vue 映射到 TypeScript
            "svelte": "typescript", // Svelte 映射到 TypeScript
            "rs": "rust",
            "go": "go",
            "c": "c",
            "cpp": "cpp",
            "h": "c",
            "hpp": "cpp",
            "m": "objective-c",
            "mm": "objective-cpp",
            "rb": "ruby",
            "java": "java",
            "kt": "kotlin",
            "php": "php",
            "sh": "bash",
            "json": "json",
            "yaml": "yaml",
            "yml": "yaml",
            "xml": "xml",
            "html": "html",
            "css": "css",
            "scss": "scss",
            "md": "markdown",
            "sql": "sql",
        ]
        return mapping[ext.lowercased()]
    }

    // MARK: - LSP Edit Utilities

    func clearMultiCursors() {
        applyMultiCursorState(EditorMultiCursorStateController.clearSecondary(from: multiCursorState))
        logMultiCursorState(action: "clearMultiCursors")
        endMultiCursorSearchSession()
    }

    func clearUnfocusedMultiCursorsIfNeeded() {
        guard multiCursorState.isEnabled else { return }
        guard multiCursorState.all.count <= 1 else { return }
        applyMultiCursorState(EditorMultiCursorStateController.clearSecondary(from: multiCursorState))
        endMultiCursorSearchSession()
    }

    func setPrimarySelection(_ selection: MultiCursorSelection) {
        applyMultiCursorState(
            EditorMultiCursorStateController.replacingPrimary(in: multiCursorState, with: selection)
        )
        logMultiCursorState(action: "setPrimarySelection")
    }

    func setSelections(_ selections: [MultiCursorSelection]) {
        guard let first = selections.first else {
            clearMultiCursors()
            return
        }
        applyMultiCursorSelections(selections)
        logMultiCursorState(action: "setSelections", note: "incomingCount=\(selections.count)")

        if selections.count != 1 {
            return
        }

        if let text = currentEditorTextStorageString(),
           let session = EditorMultiCursorSearchController.collapsedSession(
                from: multiCursorSearchSession,
                singleSelection: first,
                in: text
           ) {
            multiCursorSearchSession = session
            return
        }

        endMultiCursorSearchSession()
    }

    func currentSelectionsAsNSRanges() -> [NSRange] {
        multiCursorState.all.map { NSRange(location: $0.location, length: $0.length) }
    }

    private func applyMultiCursorSelections(_ selections: [MultiCursorSelection]) {
        applyMultiCursorState(EditorMultiCursorStateController.state(from: selections))
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

        let viewState = EditorViewStateController.positions(
            from: selections,
            text: text,
            fallbackLine: max(cursorLine, 1),
            fallbackColumn: max(cursorColumn, 1),
            positionResolver: editorPosition(utf16Offset:in:)
        )
        navigateToCursorPositions(viewState.cursorPositions)
    }

    func logMultiCursorState(action: String, note: String? = nil) {
        let selections = multiCursorState.all
        let summary = selections.enumerated().map { index, selection in
            "#\(index){loc=\(selection.location),len=\(selection.length)}"
        }.joined(separator: ", ")
        let message = note.map { "\(action) | \($0) | stateCount=\(selections.count) | [\(summary)]" }
            ?? "\(action) | stateCount=\(selections.count) | [\(summary)]"
        EditorPlugin.logger.info("[UI] | ✏️ 编辑器状态 | 多光标状态 | \(message, privacy: .public)")
    }

    func logMultiCursorInput(action: String, textViewSelections: [NSRange], note: String? = nil) {
        let rendered = textViewSelections.enumerated().map { index, range in
            "#\(index){\(NSStringFromRange(range))}"
        }.joined(separator: ", ")
        let details = note.map { "\(action) | \($0) | textViewCount=\(textViewSelections.count) | [\(rendered)]" }
            ?? "\(action) | textViewCount=\(textViewSelections.count) | [\(rendered)]"
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
        guard let text = currentEditorTextStorageString() else { return nil }
        let normalizedRange = EditorMultiCursorMatcher.normalizedRange(range, in: text)
        guard normalizedRange.location != NSNotFound else { return nil }
        guard let resolved = EditorMultiCursorSearchController.resolvedContext(
            from: normalizedRange,
            in: text,
            existingSession: multiCursorSearchSession
        ) else {
            showStatusToast(
                String(localized: "Select text before adding next occurrence", table: "LumiEditor"),
                level: .warning
            )
            return nil
        }

        let context = resolved.context
        if resolved.shouldStartSession {
            multiCursorSearchSession = EditorMultiCursorSearchController.session(for: context)
            applyMultiCursorState(EditorMultiCursorStateController.state(from: [context.baseSelection]))
            logMultiCursorState(action: "addNextOccurrence.sessionStarted", note: "query=\(context.query)")
        }

        let allMatches = EditorMultiCursorMatcher.ranges(of: context.query, in: text)

        guard !allMatches.isEmpty else { return currentSelectionsAsNSRanges() }

        guard let session = multiCursorSearchSession else {
            return currentSelectionsAsNSRanges()
        }

        if let candidate = EditorMultiCursorSearchController.nextSelection(
            in: allMatches,
            currentState: multiCursorState,
            session: session
        ) {
            applyMultiCursorState(
                EditorMultiCursorStateController.addingSelection(candidate, to: multiCursorState)
            )
            multiCursorSearchSession = EditorMultiCursorSearchController.appending(
                candidate,
                to: session
            )
            logMultiCursorState(action: "addNextOccurrence.added", note: "query=\(context.query)")
            return currentSelectionsAsNSRanges()
        }

        showStatusToast(
            String(localized: "No more occurrences found", table: "LumiEditor"),
            level: .warning
        )
        return currentSelectionsAsNSRanges()
    }

    func addAllOccurrences(from range: NSRange) -> [NSRange]? {
        guard let text = currentEditorTextStorageString() else { return nil }
        let normalizedRange = EditorMultiCursorMatcher.normalizedRange(range, in: text)
        guard normalizedRange.location != NSNotFound else { return nil }

        guard let context = EditorMultiCursorMatcher.searchContext(from: normalizedRange, in: text) else {
            showStatusToast(
                String(localized: "Select text before selecting all occurrences", table: "LumiEditor"),
                level: .warning
            )
            return nil
        }

        let matches = EditorMultiCursorMatcher.ranges(of: context.query, in: text)
        guard !matches.isEmpty else { return nil }

        multiCursorSearchSession = EditorMultiCursorSearchController.session(
            for: context,
            matches: matches
        )
        applyMultiCursorSelections(matches)
        logMultiCursorState(action: "addAllOccurrences", note: "query=\(context.query)")
        return currentSelectionsAsNSRanges()
    }

    func removeLastOccurrenceSelection() -> [NSRange]? {
        guard multiCursorState.isEnabled else { return nil }
        guard let session = multiCursorSearchSession else {
            clearMultiCursors()
            return currentSelectionsAsNSRanges()
        }
        guard let updatedSession = EditorMultiCursorSearchController.removingLast(from: session) else {
            clearMultiCursors()
            return currentSelectionsAsNSRanges()
        }

        multiCursorSearchSession = updatedSession
        applyMultiCursorSelections(updatedSession.history)
        logMultiCursorState(action: "removeLastOccurrenceSelection")
        return currentSelectionsAsNSRanges()
    }

    func multiCursorSummaryText() -> String {
        let count = multiCursorState.all.count
        if count <= 1 { return "1" }
        return "\(count)" + String(localized: " cursors", table: "LumiEditor")
    }

    func applyMultiCursorReplacement(_ replacement: String) -> [MultiCursorSelection]? {
        guard let text = documentController.buffer?.text ?? content?.string else { return nil }
        let selections = multiCursorState.all
        guard selections.count > 1 else { return nil }

        let result = MultiCursorEditEngine.apply(
            text: text,
            selections: selections,
            operation: .replaceSelection(replacement)
        )

        let transaction = MultiCursorTransactionBuilder.makeTransaction(
            operation: .replaceSelection(replacement),
            selections: selections,
            updatedSelections: result.selections
        )
        applyEditorTransaction(transaction, reason: "multi_cursor_replace")
        endMultiCursorSearchSession()
        return result.selections
    }

    func applyMultiCursorOperation(_ operation: MultiCursorOperation) -> [MultiCursorSelection]? {
        guard let text = documentController.buffer?.text ?? content?.string else { return nil }
        let selections = multiCursorState.all
        guard selections.count > 1 else { return nil }

        let result = MultiCursorEditEngine.apply(
            text: text,
            selections: selections,
            operation: operation
        )

        let transaction: EditorTransaction
        switch operation {
        case .indent, .outdent:
            transaction = EditorTransaction(
                replacements: [
                    .init(
                        range: EditorRange(location: 0, length: (text as NSString).length),
                        text: result.text
                    )
                ],
                updatedSelections: result.selections.map {
                    EditorSelection(
                        range: EditorRange(location: $0.location, length: $0.length)
                    )
                }
            )
        default:
            transaction = MultiCursorTransactionBuilder.makeTransaction(
                operation: operation,
                selections: selections,
                updatedSelections: result.selections
            )
        }
        applyEditorTransaction(transaction, reason: "multi_cursor_operation")
        return result.selections
    }

    private func currentLSPPosition() -> (line: Int, character: Int) {
        (
            max(cursorLine - 1, 0),
            max(cursorColumn - 1, 0)
        )
    }

    // MARK: - Text Edit Application (Transaction-First)
    //
    // 所有文本编辑应用最终都通过 documentController 的 transaction 路径落地，
    // 然后统一进入 commitDocumentEditResult 进行后处理（selection 同步、LSP 通知、行数更新等）。

    /// 将 LSP TextEdits 应用到当前文档，走 transaction 路径。
    /// 这是 Phase 1 "format / rename / code action 走 transaction" 的核心入口。
    private func applyTextEditsToCurrentDocument(_ edits: [TextEdit], reason: String = "text_edits") {
        guard let result = documentController.applyTextEdits(edits) else { return }
        commitDocumentEditResult(result, reason: reason)
    }

    /// Code Action 的 WorkspaceEdit 统一入口。
    /// 当前文件的 edits 走 transaction；其他文件直接写磁盘。
    /// 这是 Phase 1 "code action text edits 走 transaction" 的落地方法。
    func applyCodeActionWorkspaceEdit(_ edit: WorkspaceEdit) {
        let currentURI = currentFileURL?.absoluteString
        _ = applyWorkspaceEditChanges(
            edit.changes,
            documentChanges: edit.documentChanges,
            currentURI: currentURI ?? ""
        )
    }

    /// 应用 workspace changes（rename 等场景）。
    /// 当前文件的 edits 走 transaction；其他文件直接写入磁盘。
    @discardableResult
    private func applyWorkspaceEditChanges(
        _ changes: [String: [TextEdit]]?,
        documentChanges: [WorkspaceEditDocumentChange]?,
        currentURI: String
    ) -> Int {
        var changedFiles = 0

        // 处理 changes 字典
        if let changes, !changes.isEmpty {
            for (uri, textEdits) in changes {
                guard !textEdits.isEmpty else { continue }
                if uri == currentURI {
                    applyTextEditsToCurrentDocument(textEdits, reason: "lsp_workspace_edit")
                    changedFiles += 1
                    continue
                }
                guard let url = URL(string: uri), url.isFileURL else { continue }
                if applyTextEditsToFile(textEdits, url: url) {
                    changedFiles += 1
                }
            }
        }

        // 处理 documentChanges 数组（优先级更高，LSP 3.16+）
        if let documentChanges {
            for change in documentChanges {
                switch change {
                case .textDocumentEdit(let item):
                    let uri = item.textDocument.uri
                    let edits = item.edits
                    guard !edits.isEmpty else { continue }

                    if uri == currentURI {
                        applyTextEditsToCurrentDocument(edits, reason: "lsp_document_edit")
                        changedFiles += 1
                    } else if let url = URL(string: uri), url.isFileURL, applyTextEditsToFile(edits, url: url) {
                        changedFiles += 1
                    }
                case .createFile(let operation):
                    if WorkspaceEditFileOperations.applyCreateFile(operation) {
                        changedFiles += 1
                    }
                case .renameFile(let operation):
                    if WorkspaceEditFileOperations.applyRenameFile(operation) {
                        changedFiles += 1
                    }
                case .deleteFile(let operation):
                    if WorkspaceEditFileOperations.applyDeleteFile(operation) {
                        changedFiles += 1
                    }
                }
            }
        }

        return changedFiles
    }

    /// 将 TextEdits 应用到非当前文件（直接写磁盘）。
    private func applyTextEditsToFile(_ edits: [TextEdit], url: URL) -> Bool {
        do {
            let original = try String(contentsOf: url, encoding: .utf8)
            guard let updated = TextEditApplier.apply(edits: edits, to: original), updated != original else {
                return false
            }
            try updated.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    private func displayPathForURL(_ url: URL) -> String {
        guard let projectPath = projectRootPath else { return url.lastPathComponent }
        let absolutePath = url.path
        guard absolutePath.hasPrefix(projectPath) else { return url.lastPathComponent }
        var relative = String(absolutePath.dropFirst(projectPath.count))
        if relative.hasPrefix("/") {
            relative.removeFirst()
        }
        return relative
    }

    private func presentInfoAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "OK", table: "LumiEditor"))
        alert.runModal()
    }

    private func previewLine(from url: URL, at lineNumber: Int) -> String? {
        guard lineNumber > 0 else { return nil }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let lines = content.components(separatedBy: .newlines)
        guard lineNumber - 1 < lines.count else { return nil }
        return lines[lineNumber - 1].trimmingCharacters(in: .whitespacesAndNewlines)
    }

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
        guard let result = documentController.apply(transaction: transaction) else { return }
        commitDocumentEditResult(result, reason: reason)
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

    // MARK: - Line Editing (Phase 9)

    /// 行编辑命令类型
    enum LineEditKind {
        case deleteLine
        case copyLineUp
        case copyLineDown
        case moveLineUp
        case moveLineDown
        case insertLineBelow
        case insertLineAbove
        case sortLinesAscending
        case sortLinesDescending
        case toggleLineComment
        case transpose
    }

    /// 执行行编辑命令
    func performLineEdit(_ kind: LineEditKind) {
        guard let text = content?.string, !text.isEmpty else { return }

        let selections = multiCursorState.all.count > 1
            ? multiCursorState.all.map { NSRange(location: $0.location, length: $0.length) }
            : focusedTextView?.selectionManager.textSelections.map(\.range)
                ?? [NSRange(location: 0, length: 0)]

        let result: LineEditResult?
        switch kind {
        case .deleteLine:
            result = LineEditingController.deleteLine(in: text, selections: selections)
        case .copyLineUp:
            result = LineEditingController.copyLineUp(in: text, selections: selections)
        case .copyLineDown:
            result = LineEditingController.copyLineDown(in: text, selections: selections)
        case .moveLineUp:
            result = LineEditingController.moveLineUp(in: text, selections: selections)
        case .moveLineDown:
            result = LineEditingController.moveLineDown(in: text, selections: selections)
        case .insertLineBelow:
            result = LineEditingController.insertLineBelow(in: text, selections: selections)
        case .insertLineAbove:
            result = LineEditingController.insertLineAbove(in: text, selections: selections)
        case .sortLinesAscending:
            result = LineEditingController.sortLines(in: text, selections: selections, descending: false)
        case .sortLinesDescending:
            result = LineEditingController.sortLines(in: text, selections: selections, descending: true)
        case .toggleLineComment:
            let commentPrefix = commentPrefixForLanguage(detectedLanguage?.tsName ?? "swift")
            result = LineEditingController.toggleLineComment(
                in: text, selections: selections, commentPrefix: commentPrefix
            )
        case .transpose:
            result = LineEditingController.transpose(in: text, selections: selections)
        }

        guard let lineEditResult = result else { return }

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

    /// 根据语言获取行注释前缀
    private func commentPrefixForLanguage(_ languageId: String) -> String {
        switch languageId {
        case "swift", "java", "javascript", "typescript", "go", "rust", "kotlin", "c", "cpp":
            return "//"
        case "python", "ruby", "perl", "r", "bash", "shell", "yaml", "toml":
            return "#"
        case "html", "xml", "svg":
            return "<!--"
        case "css", "scss", "less":
            return "/*"
        case "lua", "sql":
            return "--"
        default:
            return "//"
        }
    }

    // MARK: - Cursor Motion

    /// 光标移动命令类型
    enum CursorMotionKind {
        case wordLeft
        case wordRight
        case wordLeftSelect
        case wordRightSelect
        case smartHome
        case smartHomeSelect
        case lineEnd
        case lineEndSelect
        case documentStart
        case documentEnd
        case deleteWordLeft
        case deleteWordRight
        case paragraphBackward
        case paragraphForward
    }

    /// 执行光标移动命令
    func performCursorMotion(_ kind: CursorMotionKind) {
        guard let text = content?.string else { return }
        guard let textView = focusedTextView else { return }

        let currentLocation = textView.selectionManager.textSelections.first?.range.location ?? 0
        let currentRange = textView.selectionManager.textSelections.first?.range
            ?? NSRange(location: 0, length: 0)

        switch kind {
        case .wordLeft:
            let target = CursorMotionController.moveWordLeft(location: currentLocation, text: text)
            applyCursorMotionTarget(target, textView: textView)

        case .wordRight:
            let target = CursorMotionController.moveWordRight(location: currentLocation, text: text)
            applyCursorMotionTarget(target, textView: textView)

        case .wordLeftSelect:
            let target = CursorMotionController.moveWordLeft(location: currentLocation, text: text)
            let anchor = currentRange.location
            let newRange = NSRange(
                location: min(anchor, target.location),
                length: abs(target.location - anchor)
            )
            textView.selectionManager.setSelectedRanges([newRange])

        case .wordRightSelect:
            let target = CursorMotionController.moveWordRight(location: currentLocation, text: text)
            let anchor = currentRange.location
            let newRange = NSRange(
                location: min(anchor, target.location),
                length: abs(target.location - anchor)
            )
            textView.selectionManager.setSelectedRanges([newRange])

        case .smartHome:
            let target = CursorMotionController.smartHome(location: currentLocation, text: text)
            applyCursorMotionTarget(target, textView: textView)

        case .smartHomeSelect:
            let target = CursorMotionController.smartHome(location: currentLocation, text: text)
            let anchor = currentRange.location
            let newRange = NSRange(
                location: min(anchor, target.location),
                length: abs(target.location - anchor)
            )
            textView.selectionManager.setSelectedRanges([newRange])

        case .lineEnd:
            let target = CursorMotionController.moveToEndOfLine(location: currentLocation, text: text)
            applyCursorMotionTarget(target, textView: textView)

        case .lineEndSelect:
            let target = CursorMotionController.moveToEndOfLine(location: currentLocation, text: text)
            let anchor = currentRange.location
            let newRange = NSRange(
                location: min(anchor, target.location),
                length: abs(target.location - anchor)
            )
            textView.selectionManager.setSelectedRanges([newRange])

        case .documentStart:
            let target = CursorMotionController.moveToDocumentStart()
            applyCursorMotionTarget(target, textView: textView)

        case .documentEnd:
            let target = CursorMotionController.moveToDocumentEnd(text: text)
            applyCursorMotionTarget(target, textView: textView)

        case .deleteWordLeft:
            let target = CursorMotionController.deleteWordLeft(location: currentLocation, text: text)
            if let deleteRange = target.selectionRange {
                let transaction = EditorTransaction(
                    replacements: [
                        .init(
                            range: EditorRange(location: deleteRange.location, length: deleteRange.length),
                            text: ""
                        )
                    ],
                    updatedSelections: [EditorSelection(range: EditorRange(location: target.location, length: 0))]
                )
                applyEditorTransaction(transaction, reason: "delete_word_left")
                textView.selectionManager.setSelectedRanges(
                    currentSelectionsAsNSRanges()
                )
            }

        case .deleteWordRight:
            let target = CursorMotionController.deleteWordRight(location: currentLocation, text: text)
            if let deleteRange = target.selectionRange {
                let transaction = EditorTransaction(
                    replacements: [
                        .init(
                            range: EditorRange(location: deleteRange.location, length: deleteRange.length),
                            text: ""
                        )
                    ],
                    updatedSelections: [EditorSelection(range: EditorRange(location: currentLocation, length: 0))]
                )
                applyEditorTransaction(transaction, reason: "delete_word_right")
                textView.selectionManager.setSelectedRanges(
                    currentSelectionsAsNSRanges()
                )
            }

        case .paragraphBackward:
            let target = CursorMotionController.moveParagraphBackward(location: currentLocation, text: text)
            applyCursorMotionTarget(target, textView: textView)

        case .paragraphForward:
            let target = CursorMotionController.moveParagraphForward(location: currentLocation, text: text)
            applyCursorMotionTarget(target, textView: textView)
        }
    }

    /// 应用光标移动目标到 TextView
    private func applyCursorMotionTarget(_ target: CursorMotionTarget, textView: TextView) {
        textView.selectionManager.setSelectedRanges([
            NSRange(location: target.location, length: 0)
        ])
    }

    private func applyInputEdit(
        replacementRange: NSRange,
        replacementText: String,
        selectedRanges: [NSRange],
        reason: String
    ) -> Bool {
        guard replacementRange.location != NSNotFound else { return false }

        let transaction = EditorTransaction(
            replacements: [
                .init(
                    range: EditorRange(
                        location: replacementRange.location,
                        length: replacementRange.length
                    ),
                    text: replacementText
                )
            ],
            updatedSelections: selectedRanges.map {
                EditorSelection(
                    range: EditorRange(
                        location: $0.location,
                        length: $0.length
                    )
                )
            }
        )
        applyEditorTransaction(transaction, reason: reason)
        return true
    }

    private func commitDocumentEditResult(_ result: EditorEditResult, reason: String) {
        content = documentController.textStorage
        totalLines = result.snapshot.text.filter { $0 == "\n" }.count + 1
        if let selections = result.selections {
            // Phase 2: 同时更新 canonical selection set 和外部 multiCursorState
            canonicalSelectionSet = EditorSelectionSet(selections: selections)
            setSelections(multiCursorSelections(from: selections))
        }
        lspCoordinator.replaceDocument(result.snapshot.text)
        notifyContentChanged()

        if Self.verbose {
            logger.info("\(Self.t)应用编辑事务: reason=\(reason), version=\(result.snapshot.version), length=\(result.snapshot.text.count)")
        }
    }

    private func multiCursorSelections(from selections: [EditorSelection]) -> [MultiCursorSelection] {
        selections.map {
            MultiCursorSelection(location: $0.range.location, length: $0.range.length)
        }
    }

    private func syncActiveSessionState(
        scrollStateOverride: EditorScrollState? = nil
    ) {
        guard !isSessionSyncSuspended else { return }

        let bridgeState = currentBridgeState()
        let scrollState = scrollStateOverride ?? focusedTextView.map { textView in
            EditorScrollState(viewportOrigin: textView.visibleRect.origin)
        } ?? activeSession.scrollState

        let snapshot = EditorSessionSnapshotBuilder.snapshot(
            preserving: activeSession.id,
            fileURL: currentFileURL,
            multiCursorState: multiCursorState,
            panelState: panelState.sessionState,
            isDirty: hasUnsavedChanges,
            bridgeState: bridgeState,
            scrollState: scrollState
        )
        activeSession.applySnapshot(from: snapshot)
        onActiveSessionChanged?(activeSession)
    }

    private func applyFindReplaceState(_ state: EditorFindReplaceState) {
        EditorFindReplaceStateController.apply(state, to: &editorState)
    }

    private func applyBridgeState(_ state: EditorBridgeState) {
        editorState.cursorPositions = state.viewState.cursorPositions
        cursorLine = state.viewState.primaryCursorLine
        cursorColumn = state.viewState.primaryCursorColumn

        if let findReplaceState = state.findReplaceState {
            applyFindReplaceState(findReplaceState)
        }
    }

    private func applyBridgeStateAndSync(_ state: EditorBridgeState) {
        applyBridgeState(state)
        syncActiveSessionState()
    }

    private func currentPanelSnapshot() -> EditorPanelSnapshot {
        panelState.snapshot
    }

    private func clearPanelData(
        clearDiagnostics: Bool = false,
        closeProblems: Bool? = nil,
        closeReferences: Bool? = nil,
        closeWorkspaceSymbols: Bool? = nil,
        closeCallHierarchy: Bool? = nil
    ) {
        panelState.clearMouseHover()
        setReferenceResults([])
        if clearDiagnostics {
            setProblemDiagnostics([])
        }
        setSelectedProblemDiagnostic(nil)
        applyPanelSnapshot(
            updatedPanelSnapshot(
                problems: closeProblems,
                references: closeReferences,
                workspaceSymbols: closeWorkspaceSymbols,
                callHierarchy: closeCallHierarchy
            )
        )
    }

    private func updatedPanelSnapshot(
        openEditors: Bool? = nil,
        problems: Bool? = nil,
        references: Bool? = nil,
        workspaceSymbols: Bool? = nil,
        callHierarchy: Bool? = nil
    ) -> EditorPanelSnapshot {
        let snapshot = currentPanelSnapshot()
        return EditorPanelSnapshot(
            isOpenEditorsPanelPresented: openEditors ?? snapshot.isOpenEditorsPanelPresented,
            isProblemsPanelPresented: problems ?? snapshot.isProblemsPanelPresented,
            isReferencePanelPresented: references ?? snapshot.isReferencePanelPresented,
            isWorkspaceSymbolSearchPresented: workspaceSymbols ?? snapshot.isWorkspaceSymbolSearchPresented,
            isCallHierarchyPresented: callHierarchy ?? snapshot.isCallHierarchyPresented
        )
    }

    private func applyPanelSnapshot(_ snapshot: EditorPanelSnapshot) {
        panelState.apply(snapshot)
    }

    private func setProblemDiagnostics(_ diagnostics: [Diagnostic]) {
        panelState.problemDiagnostics = diagnostics
    }

    private func setSelectedProblemDiagnostic(_ diagnostic: Diagnostic?) {
        panelState.selectedProblemDiagnostic = diagnostic
    }

    private func setReferenceResults(_ results: [ReferenceResult]) {
        panelState.referenceResults = results.map(Self.editorReferenceResult(from:))
    }

    private func syncPublishedPanelDataFromPanelState() {
        isOpenEditorsPanelPresented = panelState.isOpenEditorsPanelPresented
        problemDiagnostics = panelState.problemDiagnostics
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
        EditorBridgeStateController.state(
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

    private func deduplicatingCommandSuggestions(_ suggestions: [EditorCommandSuggestion]) -> [EditorCommandSuggestion] {
        var seen = Set<String>()
        let deduplicated = suggestions.filter { suggestion in
            seen.insert(suggestion.id).inserted
        }
        return deduplicated.sortedForCommandPresentation()
    }

    private func applyFindMatchesResult(_ result: EditorFindMatchesResult) {
        findMatches = result.matches

        var state = activeSession.findReplaceState
        state.resultCount = result.matches.count
        state.selectedMatchIndex = result.selectedMatchIndex
        state.selectedMatchRange = result.selectedMatchRange
        applyFindReplaceState(state)
        activeSession.findReplaceState = state
    }

    private func selectFindMatch(at index: Int) {
        guard findMatches.indices.contains(index),
              let text = content?.string else { return }

        let match = findMatches[index]
        let selection = MultiCursorSelection(location: match.range.location, length: match.range.length)
        applyMultiCursorSelections([selection])

        let cursorPositions = EditorViewStateController.positions(
            from: [selection],
            text: text,
            fallbackLine: max(cursorLine, 1),
            fallbackColumn: max(cursorColumn, 1),
            positionResolver: editorPosition(utf16Offset:in:)
        ).cursorPositions
        navigateToCursorPositions(cursorPositions)

        var state = activeSession.findReplaceState
        state.selectedMatchIndex = index
        state.selectedMatchRange = match.range
        applyFindReplaceState(state)
        syncActiveSessionState()
    }

    private func withoutSessionSync(_ operation: () -> Void) {
        let previousValue = isSessionSyncSuspended
        isSessionSyncSuspended = true
        operation()
        isSessionSyncSuspended = previousValue
    }

    private func restoreScrollState(_ state: EditorScrollState) {
        guard let textView = focusedTextView,
              let scrollView = textView.enclosingScrollView else { return }
        let clipView = scrollView.contentView
        clipView.scroll(to: state.viewportOrigin)
        scrollView.reflectScrolledClipView(clipView)
    }

    private func restorePanelState(from session: EditorSession) {
        let sessionPanelState = session.panelState
        panelState.restore(from: sessionPanelState)
        applyPanelSnapshot(
            updatedPanelSnapshot(
                problems: session.panelSnapshot.isProblemsPanelPresented,
                references: session.panelSnapshot.isReferencePanelPresented,
                workspaceSymbols: session.panelSnapshot.isWorkspaceSymbolSearchPresented,
                callHierarchy: session.panelSnapshot.isCallHierarchyPresented
            )
        )
    }

    private func multiCursorCursorPositions(from selections: [MultiCursorSelection]) -> [CursorPosition] {
        guard let text = content?.string else { return [] }
        let viewState = EditorViewStateController.positions(
            from: selections,
            text: text,
            fallbackLine: max(cursorLine, 1),
            fallbackColumn: max(cursorColumn, 1),
            positionResolver: editorPosition(utf16Offset:in:)
        )
        return viewState.cursorPositions
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
        multiCursorSearchSession = nil
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

// MARK: - String Helpers

private extension String {
    func getFirstLines(_ count: Int) -> String? {
        var lines = 0
        for (idx, char) in self.enumerated() {
            if char == "\n" {
                lines += 1
                if lines >= count {
                    let index = self.index(self.startIndex, offsetBy: idx)
                    return String(self[..<index])
                }
            }
        }
        return nil
    }
    
    func getLastLines(_ count: Int) -> String? {
        var lines = 0
        for (idx, char) in self.enumerated().reversed() {
            if char == "\n" {
                lines += 1
                if lines >= count {
                    let index = self.index(self.startIndex, offsetBy: idx + 1)
                    return String(self[index...])
                }
            }
        }
        return nil
    }
}
