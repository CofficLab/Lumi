import Foundation
import AppKit
import Combine
import MagicAlert
import CodeEditSourceEditor
import CodeEditTextView
import CodeEditLanguages
import LanguageServerProtocol

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
@MainActor
final class EditorState: ObservableObject {
    enum StatusLevel {
        case info
        case success
        case warning
        case error
    }

    private struct MultiCursorSearchSession {
        let query: String
        let baseSelection: MultiCursorSelection
        var history: [MultiCursorSelection]
    }

    // MARK: - Problems

    /// 当前文件的诊断列表（Problems 面板数据源）
    @Published var problemDiagnostics: [Diagnostic] = []

    /// 当前选中的问题，用于列表高亮与编辑器同步
    @Published var selectedProblemDiagnostic: Diagnostic?

    /// 是否展示 Problems 面板
    @Published var isProblemsPanelPresented: Bool = false

    private var diagnosticsCancellable: AnyCancellable?
    private var multiCursorSearchSession: MultiCursorSearchSession?

    private func bindDiagnostics() {
        diagnosticsCancellable?.cancel()
        diagnosticsCancellable = LSPService.shared.$currentDiagnostics
            .receive(on: RunLoop.main)
            .sink { [weak self] diags in
                self?.problemDiagnostics = diags
                if let selected = self?.selectedProblemDiagnostic,
                   diags.contains(where: { $0 == selected }) == false {
                    self?.selectedProblemDiagnostic = nil
                }
                // 面板打开时保持打开；面板关闭时不强制弹出
            }
    }

    func toggleProblemsPanel() {
        if isProblemsPanelPresented {
            isProblemsPanelPresented = false
        } else {
            // 打开 problems 时优先关闭 references，避免右侧面板冲突
            isReferencePanelPresented = false
            isProblemsPanelPresented = true
        }
    }

    func closeProblemsPanel() {
        isProblemsPanelPresented = false
    }

    func openProblem(_ diag: Diagnostic) {
        selectedProblemDiagnostic = diag
        let line = Int(diag.range.start.line) + 1
        let column = Int(diag.range.start.character) + 1
        let endLine = Int(diag.range.end.line) + 1
        let endColumn = Int(diag.range.end.character) + 1
        let hasSelection = endLine > line || endColumn > column

        editorState.cursorPositions = [
            CursorPosition(
                start: .init(line: line, column: column),
                end: hasSelection
                    ? .init(line: endLine, column: endColumn)
                    : nil
            )
        ]
    }
    
    // MARK: - External File Watching
    
    /// 轮询定时器
    private var pollTimer: Timer?
    
    /// 上次已知的文件修改日期
    private var lastKnownModificationDate: Date?
    
    /// 轮询间隔（秒）
    private static let pollInterval: TimeInterval = 1.0
    
    // MARK: - File State
    
    /// 当前文件 URL
    @Published private(set) var currentFileURL: URL?
    
    /// 当前文件内容（NSTextStorage，CodeEditSourceEditor 要求）
    @Published var content: NSTextStorage?
    
    /// 上次持久化的内容哈希（用于检测变更）
    private var persistedContentHash: Int?
    
    /// LSP 协调器（用于语言服务器集成）
    let lspCoordinator = LSPCoordinator()
    
    // MARK: - New LSP Providers
    
    /// 签名帮助提供者
    let signatureHelpProvider = SignatureHelpProvider()
    /// 内联提示提供者
    let inlayHintProvider = InlayHintProvider()
    /// 文档高亮提供者
    let documentHighlightProvider = DocumentHighlightProvider()
    /// 代码动作提供者
    let codeActionProvider = CodeActionProvider()
    
    /// 跳转定义代理（右键和 Cmd+Click 共享）
    weak var jumpDelegate: EditorJumpToDefinitionDelegate?
    
    /// 当前文件是否可编辑
    @Published var isEditable: Bool = true
    
    /// 当前文件是否为截断预览
    @Published var isTruncated: Bool = false
    
    /// 当前文件是否可预览
    @Published var canPreview: Bool = false
    
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

    /// 当前 LSP Hover 文本（用于提示展示）
    @Published var hoverText: String?

    /// 多光标编辑状态
    @Published var multiCursorState = MultiCursorState()

    /// References 结果列表（右侧面板）
    @Published var referenceResults: [ReferenceResult] = []

    /// 是否展示 References 面板
    @Published var isReferencePanelPresented: Bool = false

    /// 总行数
    @Published var totalLines: Int = 0
    
    /// 检测到的语言
    @Published var detectedLanguage: CodeLanguage?
    
    // MARK: - Theme
    
    /// 当前主题预设
    @Published var themePreset: EditorThemeAdapter.PresetTheme = .xcodeDark
    
    /// 当前主题（缓存，避免每次重建）
    @Published private(set) var currentTheme: EditorTheme?
    
    // MARK: - Configuration
    
    /// 字体大小
    @Published var fontSize: Double = 13.0
    
    /// Tab 宽度
    @Published var tabWidth: Int = 4
    
    /// 是否使用空格替代 Tab
    @Published var useSpaces: Bool = true
    
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
    
    /// 防抖保存任务
    private var saveTask: Task<Void, Never>?
    
    /// 成功状态清除任务
    private var successClearTask: Task<Void, Never>?

    /// 自动保存延迟（秒）
    static let autoSaveDelay: TimeInterval = 1.5
    
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
        case error(String)
        
        var icon: String {
            switch self {
            case .idle: return "checkmark.circle"
            case .editing: return "pencil.circle"
            case .saving: return "arrow.triangle.2.circlepath"
            case .saved: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }
        
        var label: String {
            switch self {
            case .idle: return String(localized: "No Changes", table: "LumiEditor")
            case .editing: return String(localized: "Editing...", table: "LumiEditor")
            case .saving: return String(localized: "Saving...", table: "LumiEditor")
            case .saved: return String(localized: "Saved", table: "LumiEditor")
            case .error(let msg): return msg
            }
        }
    }
    
    // MARK: - Init
    
    init() {
        bindDiagnostics()
        restoreConfig()
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
        // 恢复主题
        if let themeRaw = EditorConfigStore.loadString(forKey: EditorConfigStore.themeNameKey),
           let preset = EditorThemeAdapter.PresetTheme(rawValue: themeRaw) {
            themePreset = preset
        }
        currentTheme = EditorThemeAdapter.theme(from: themePreset)
    }
    
    /// 持久化当前配置
    func persistConfig() {
        EditorConfigStore.saveValue(fontSize, forKey: EditorConfigStore.fontSizeKey)
        EditorConfigStore.saveValue(tabWidth, forKey: EditorConfigStore.tabWidthKey)
        EditorConfigStore.saveValue(useSpaces, forKey: EditorConfigStore.useSpacesKey)
        EditorConfigStore.saveValue(wrapLines, forKey: EditorConfigStore.wrapLinesKey)
        EditorConfigStore.saveValue(showMinimap, forKey: EditorConfigStore.showMinimapKey)
        EditorConfigStore.saveValue(showGutter, forKey: EditorConfigStore.showGutterKey)
        EditorConfigStore.saveValue(showFoldingRibbon, forKey: EditorConfigStore.showFoldingRibbonKey)
        EditorConfigStore.saveValue(themePreset.rawValue, forKey: EditorConfigStore.themeNameKey)
        EditorConfigStore.saveValue(sidePanelWidth, forKey: EditorConfigStore.sidePanelWidthKey)
    }
    
    /// 切换主题
    func setTheme(_ preset: EditorThemeAdapter.PresetTheme) {
        themePreset = preset
        currentTheme = EditorThemeAdapter.theme(from: preset)
        persistConfig()

        // 通知终端插件同步更新颜色
        NotificationCenter.default.post(
            name: .lumiEditorThemeDidChange,
            object: nil,
            userInfo: ["theme": preset]
        )
    }
    
    // MARK: - File Loading
    
    /// 加载指定文件
    func loadFile(from url: URL?) {
        // 清理旧状态
        saveTask?.cancel()
        saveTask = nil
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
                        self?.resetState()
                    }
                    return
                }
                
                let shouldTruncate = fileSize > Self.truncationThreshold
                let shouldReadOnly = fileSize > Self.readOnlyThreshold
                
                let content: String
                if shouldTruncate {
                    content = try readTruncatedContent(from: url, maxBytes: Self.truncationReadBytes)
                } else {
                    var detectedEncoding = String.Encoding.utf8
                    content = try String(contentsOf: url, usedEncoding: &detectedEncoding)
                }
                
                await MainActor.run { [weak self] in
                    guard let self, self.currentFileURL != loadingURL || self.content == nil else { return }
                    
                    self.currentFileURL = loadingURL
                    self.content = NSTextStorage(string: content)
                    self.persistedContentHash = content.hashValue
                    self.canPreview = true
                    self.isEditable = !shouldReadOnly
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
                    
                    // 计算行数
                    self.totalLines = content.filter { $0 == "\n" }.count + 1
                    self.hoverText = nil
                    self.referenceResults = []
                    self.isReferencePanelPresented = false
                    self.selectedProblemDiagnostic = nil
                    self.isProblemsPanelPresented = false
                    
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

    /// 从跳转定义入口打开文件并移动光标
    func openDefinitionLocation(url: URL, target: CursorPosition, highlightLine: Bool = false) {
        loadFile(from: url)
        Task { @MainActor [weak self] in
            guard let self else { return }
            for _ in 0..<40 {
                if self.currentFileURL == url, self.content != nil {
                    let finalTarget = highlightLine
                        ? self.lineHighlightCursorPosition(from: target)
                        : target
                    self.editorState.cursorPositions = [finalTarget]
                    return
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
            let finalTarget = highlightLine
                ? self.lineHighlightCursorPosition(from: target)
                : target
            self.editorState.cursorPositions = [finalTarget]
        }
    }

    private func lineHighlightCursorPosition(from target: CursorPosition) -> CursorPosition {
        let line = max(target.start.line, 1)
        guard let content else {
            return CursorPosition(
                start: .init(line: line, column: 1),
                end: .init(line: line, column: max(target.start.column, 1))
            )
        }

        let lines = content.string.components(separatedBy: .newlines)
        let index = line - 1
        guard lines.indices.contains(index) else {
            return CursorPosition(
                start: .init(line: line, column: 1),
                end: .init(line: line, column: max(target.start.column, 1))
            )
        }

        let lineText = lines[index]
        let endColumn = max(lineText.count + 1, target.start.column)
        return CursorPosition(
            start: .init(line: line, column: 1),
            end: .init(line: line, column: endColumn)
        )
    }
    
    /// 重置状态
    private func resetState() {
        currentFileURL = nil
        content = nil
        persistedContentHash = nil
        canPreview = false
        isEditable = true
        isTruncated = false
        fileExtension = ""
        fileName = ""
        hasUnsavedChanges = false
        saveState = .idle
        detectedLanguage = nil
        cursorLine = 1
        cursorColumn = 1
        totalLines = 0
        hoverText = nil
        referenceResults = []
        isReferencePanelPresented = false
        problemDiagnostics = []
        selectedProblemDiagnostic = nil
        isProblemsPanelPresented = false
        
        // 清理文件监听器
        cleanupFileWatcher()
        
        // 关闭 LSP 文档
        lspCoordinator.closeFile()
    }
    
    // MARK: - Content Change Detection
    
    /// 通知内容已变更（由 TextViewCoordinator 调用）
    func notifyContentChanged() {
        guard let content else {
            print("⚠️ [Editor] notifyContentChanged: content is nil")
            return
        }
        guard let currentHash = persistedContentHash else {
            print("⚠️ [Editor] notifyContentChanged: persistedContentHash is nil")
            return
        }
        
        let contentString = content.string
        let newHash = contentString.hashValue
        print("✏️ [Editor] notifyContentChanged: newHash=\(newHash), persistedHash=\(currentHash), changed=\(newHash != currentHash), contentLength=\(contentString.count)")
        
        if newHash != currentHash {
            hasUnsavedChanges = true
            saveState = .editing
            scheduleAutoSave(content: contentString)
            lspCoordinator.updateDocumentSnapshot(contentString)
        } else {
            hasUnsavedChanges = false
            saveState = .idle
        }
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
        applyEditsToCurrentDocument(edits)
        showStatusToast(
            String(localized: "Document formatted", table: "LumiEditor"),
            level: .success
        )
    }

    /// 查询当前光标位置的引用并弹窗展示
    func showReferencesFromCurrentCursor() async {
        guard let fileURL = currentFileURL else { return }
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
        guard !references.isEmpty else {
            referenceResults = []
            isReferencePanelPresented = false
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

        referenceResults = items.sorted {
            if $0.path != $1.path { return $0.path < $1.path }
            if $0.line != $1.line { return $0.line < $1.line }
            return $0.column < $1.column
        }
        isReferencePanelPresented = !referenceResults.isEmpty
        showStatusToast(
            String(localized: "Found references:", table: "LumiEditor") + " \(referenceResults.count)",
            level: .success
        )
    }

    func closeReferencePanel() {
        isReferencePanelPresented = false
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

    func openReference(_ reference: ReferenceResult) {
        let target = CursorPosition(
            start: CursorPosition.Position(line: reference.line, column: reference.column),
            end: nil
        )
        openDefinitionLocation(url: reference.url, target: target)
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
        changedFiles += applyWorkspaceChanges(edit.changes, currentURI: currentURI)
        changedFiles += applyDocumentChanges(edit.documentChanges, currentURI: currentURI)

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
    
    // MARK: - Auto Save
    
    /// 安排自动保存
    private func scheduleAutoSave(content: String) {
        saveTask?.cancel()
        
        let fileURL = currentFileURL
        
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.autoSaveDelay))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.performSave(content: content, to: fileURL)
            }
        }
    }
    
    /// 立即保存
    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        
        guard let content = content?.string, let fileURL = currentFileURL else { return }
        performSave(content: content, to: fileURL)
    }
    
    /// 执行保存
    private func performSave(content: String, to url: URL?) {
        guard let url else {
            print("⚠️ [Editor] performSave: url is nil")
            return
        }
        
        print("💾 [Editor] performSave: saving to \(url.path), contentLength=\(content.count)")
        saveState = .saving
        
        // 使用普通 Task（继承 MainActor 隔离），文件 I/O 通过 withCheckedThrowingContinuation 移到后台线程
        // 避免 Task.detached 导致的 "sending self risks causing data races" 编译错误
        Task {
            do {
                guard FileManager.default.fileExists(atPath: url.path) else {
                    print("⚠️ [Editor] performSave: file not found at \(url.path)")
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
                
                print("✅ [Editor] performSave: saved successfully")
                persistedContentHash = content.hashValue
                hasUnsavedChanges = false
                saveState = .saved
                scheduleSuccessClear()
            } catch {
                print("❌ [Editor] performSave: \(error)")
                saveState = .error(String(localized: "Save failed", table: "LumiEditor") + ": \(error.localizedDescription)")
                scheduleSuccessClear()
            }
        }
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
        
        print("✏️ [Editor] 已启动文件轮询监听：\(url.lastPathComponent)")
    }
    
    /// 停止文件监听
    private func cleanupFileWatcher() {
        pollTimer?.invalidate()
        pollTimer = nil
        lastKnownModificationDate = nil
    }
    
    /// 轮询检查文件是否变化
    private func pollFileChange(url: URL) {
        // 有未保存修改时不覆盖
        guard !hasUnsavedChanges else { return }
        
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
        let currentHash = currentContent.hashValue
        
        Task {
            do {
                let fileHandle = try FileHandle(forReadingFrom: url)
                let data = try fileHandle.readToEnd()
                try fileHandle.close()
                
                guard let data, let newContent = String(data: data, encoding: .utf8) else { return }
                let newHash = newContent.hashValue
                
                guard newHash != currentHash else {
                    // 内容没变，只更新修改日期
                    self.lastKnownModificationDate = currentModDate
                    return
                }
                
                self.applyExternalContent(newContent, modificationDate: currentModDate)
            } catch {
                print("⚠️ [Editor] 读取外部文件失败：\(error)")
            }
        }
    }
    
    /// 应用外部修改到编辑器
    private func applyExternalContent(_ newContent: String, modificationDate: Date) {
        guard !hasUnsavedChanges else { return }
        
        print("🔄 [Editor] 检测到外部修改，重新加载：\(currentFileURL?.lastPathComponent ?? "")")
        
        // 关键：原地替换现有 NSTextStorage 的内容，而不是创建新对象
        // SourceEditor 持有的是旧 NSTextStorage 的引用，替换引用不会触发 UI 更新
        if let existingContent = content {
            existingContent.mutableString.setString(newContent)
        } else {
            content = NSTextStorage(string: newContent)
        }
        
        persistedContentHash = newContent.hashValue
        lastKnownModificationDate = modificationDate
        hasUnsavedChanges = false
        saveState = .idle
        totalLines = newContent.filter { $0 == "\n" }.count + 1
        
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
        multiCursorState.clearSecondary()
        logMultiCursorState(action: "clearMultiCursors")
        endMultiCursorSearchSession()
    }

    func clearUnfocusedMultiCursorsIfNeeded() {
        guard multiCursorState.isEnabled else { return }
        guard multiCursorState.all.count <= 1 else { return }
        multiCursorState.clearSecondary()
        endMultiCursorSearchSession()
    }

    func setPrimarySelection(_ selection: MultiCursorSelection) {
        multiCursorState.setPrimary(selection)
        logMultiCursorState(action: "setPrimarySelection")
    }

    func setSelections(_ selections: [MultiCursorSelection]) {
        guard let first = selections.first else {
            clearMultiCursors()
            return
        }
        multiCursorState.primary = first
        multiCursorState.secondary = Array(selections.dropFirst())
        logMultiCursorState(action: "setSelections", note: "incomingCount=\(selections.count)")

        if selections.count != 1 {
            return
        }

        if let session = multiCursorSearchSession,
           session.baseSelection == first,
           selectionText(for: first) == session.query {
            multiCursorSearchSession?.history = [first]
            return
        }

        endMultiCursorSearchSession()
    }

    func currentSelectionsAsNSRanges() -> [NSRange] {
        multiCursorState.all.map { NSRange(location: $0.location, length: $0.length) }
    }

    func logMultiCursorState(action: String, note: String? = nil) {
        let selections = multiCursorState.all
        let summary = selections.enumerated().map { index, selection in
            "#\(index){loc=\(selection.location),len=\(selection.length)}"
        }.joined(separator: ", ")
        let message = note.map { "\(action) | \($0) | stateCount=\(selections.count) | [\(summary)]" }
            ?? "\(action) | stateCount=\(selections.count) | [\(summary)]"
        EditorPlugin.logger.info("[UI] | ✏️ EditorState             | multi-cursor state | \(message, privacy: .public)")
    }

    func logMultiCursorInput(action: String, textViewSelections: [NSRange], note: String? = nil) {
        let rendered = textViewSelections.enumerated().map { index, range in
            "#\(index){\(NSStringFromRange(range))}"
        }.joined(separator: ", ")
        let details = note.map { "\(action) | \($0) | textViewCount=\(textViewSelections.count) | [\(rendered)]" }
            ?? "\(action) | textViewCount=\(textViewSelections.count) | [\(rendered)]"
        EditorPlugin.logger.info("[UI] | ✏️ EditorState             | multi-cursor input | \(details, privacy: .public)")
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
        guard let content else { return nil }
        let text = content.string as NSString
        let normalizedRange = normalizedRange(range, in: text)
        guard normalizedRange.location != NSNotFound else { return nil }

        let baseSelection: MultiCursorSelection
        let query: String

        // 检查当前选区的文本是否与旧 session 的 query 匹配
        // 只有当前选区文本和旧 session 的 query 一致时才复用 session
        let currentSelectionText: String? = {
            if normalizedRange.length > 0 {
                return text.substring(with: normalizedRange)
            }
            return nil
        }()

        if let session = multiCursorSearchSession,
           selectionText(for: session.baseSelection) == session.query,
           currentSelectionText == session.query {
            baseSelection = session.baseSelection
            query = session.query
        } else {
            guard let resolvedSelection = resolvedBaseSelection(from: normalizedRange, in: text) else {
                showStatusToast(
                    String(localized: "Select text before adding next occurrence", table: "LumiEditor"),
                    level: .warning
                )
                return nil
            }

            let resolvedQuery = text.substring(with: nsRange(from: resolvedSelection))
            guard !resolvedQuery.isEmpty else { return nil }

            baseSelection = resolvedSelection
            query = resolvedQuery

            multiCursorSearchSession = MultiCursorSearchSession(
                query: query,
                baseSelection: baseSelection,
                history: [baseSelection]
            )
            multiCursorState.replaceAll([baseSelection])
            logMultiCursorState(action: "addNextOccurrence.sessionStarted", note: "query=\(query)")
        }

        let allMatches = ranges(of: query, in: text)
        let selectedSet = Set(multiCursorState.all)
        let anchorIndex = allMatches.firstIndex(of: baseSelection)
            ?? allMatches.firstIndex(of: multiCursorState.primary)
            ?? 0

        guard !allMatches.isEmpty else { return currentSelectionsAsNSRanges() }

        for step in 1...allMatches.count {
            let candidate = allMatches[(anchorIndex + step) % allMatches.count]
            if !selectedSet.contains(candidate) {
                multiCursorState.addSecondary(candidate)
                multiCursorSearchSession?.history.append(candidate)
                logMultiCursorState(action: "addNextOccurrence.added", note: "query=\(query)")
                return currentSelectionsAsNSRanges()
            }
        }

        showStatusToast(
            String(localized: "No more occurrences found", table: "LumiEditor"),
            level: .warning
        )
        return currentSelectionsAsNSRanges()
    }

    func addAllOccurrences(from range: NSRange) -> [NSRange]? {
        guard let content else { return nil }
        let text = content.string as NSString
        let normalizedRange = normalizedRange(range, in: text)
        guard normalizedRange.location != NSNotFound else { return nil }

        let baseSelection = resolvedBaseSelection(from: normalizedRange, in: text)
        guard let baseSelection else {
            showStatusToast(
                String(localized: "Select text before selecting all occurrences", table: "LumiEditor"),
                level: .warning
            )
            return nil
        }

        let query = text.substring(with: nsRange(from: baseSelection))
        guard !query.isEmpty else { return nil }

        let matches = ranges(of: query, in: text)
        guard !matches.isEmpty else { return nil }

        multiCursorSearchSession = MultiCursorSearchSession(
            query: query,
            baseSelection: baseSelection,
            history: matches
        )
        multiCursorState.replaceAll(matches)
        logMultiCursorState(action: "addAllOccurrences", note: "query=\(query)")
        return currentSelectionsAsNSRanges()
    }

    func removeLastOccurrenceSelection() -> [NSRange]? {
        guard multiCursorState.isEnabled else { return nil }
        guard var session = multiCursorSearchSession else {
            clearMultiCursors()
            return currentSelectionsAsNSRanges()
        }
        guard session.history.count > 1 else {
            clearMultiCursors()
            return currentSelectionsAsNSRanges()
        }

        session.history.removeLast()
        multiCursorSearchSession = session
        multiCursorState.replaceAll(session.history)
        logMultiCursorState(action: "removeLastOccurrenceSelection")
        return currentSelectionsAsNSRanges()
    }

    func multiCursorSummaryText() -> String {
        let count = multiCursorState.all.count
        if count <= 1 { return "1" }
        return "\(count)" + String(localized: " cursors", table: "LumiEditor")
    }

    func applyMultiCursorReplacement(_ replacement: String) -> [MultiCursorSelection]? {
        guard let existing = content else { return nil }
        let selections = multiCursorState.all
        guard selections.count > 1 else { return nil }

        let result = MultiCursorEditEngine.apply(
            text: existing.string,
            selections: selections,
            operation: .replaceSelection(replacement)
        )

        existing.mutableString.setString(result.text)
        totalLines = result.text.filter { $0 == "\n" }.count + 1
        setSelections(result.selections)
        lspCoordinator.replaceDocument(result.text)
        notifyContentChanged()
        endMultiCursorSearchSession()
        return result.selections
    }

    private func currentLSPPosition() -> (line: Int, character: Int) {
        (
            max(cursorLine - 1, 0),
            max(cursorColumn - 1, 0)
        )
    }

    private func applyEditsToCurrentDocument(_ edits: [TextEdit]) {
        guard let existing = content else { return }
        let original = existing.string
        guard let updated = Self.applyingTextEdits(edits, to: original), updated != original else { return }

        existing.mutableString.setString(updated)
        totalLines = updated.filter { $0 == "\n" }.count + 1
        lspCoordinator.replaceDocument(updated)
        notifyContentChanged()
    }

    private func applyWorkspaceChanges(
        _ changes: [String: [TextEdit]]?,
        currentURI: String
    ) -> Int {
        guard let changes, !changes.isEmpty else { return 0 }
        var changedFiles = 0

        for (uri, textEdits) in changes {
            guard !textEdits.isEmpty else { continue }
            if uri == currentURI {
                applyEditsToCurrentDocument(textEdits)
                changedFiles += 1
                continue
            }
            guard let url = URL(string: uri), url.isFileURL else { continue }
            if applyTextEdits(textEdits, toFile: url) {
                changedFiles += 1
            }
        }
        return changedFiles
    }

    private func applyDocumentChanges(
        _ documentChanges: [WorkspaceEditDocumentChange]?,
        currentURI: String
    ) -> Int {
        guard let documentChanges else { return 0 }
        var changedFiles = 0

        for change in documentChanges {
            switch change {
            case .textDocumentEdit(let item):
                let uri = item.textDocument.uri
                let edits = item.edits
                guard !edits.isEmpty else { continue }

                if uri == currentURI {
                    applyEditsToCurrentDocument(edits)
                    changedFiles += 1
                } else if let url = URL(string: uri), url.isFileURL, applyTextEdits(edits, toFile: url) {
                    changedFiles += 1
                }
            case .createFile, .renameFile, .deleteFile:
                // 资源操作（创建/重命名/删除）暂不在当前轮支持
                continue
            }
        }

        return changedFiles
    }

    private func applyTextEdits(_ edits: [TextEdit], toFile url: URL) -> Bool {
        do {
            let original = try String(contentsOf: url, encoding: .utf8)
            guard let updated = Self.applyingTextEdits(edits, to: original), updated != original else {
                return false
            }
            try updated.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    private static func applyingTextEdits(_ edits: [TextEdit], to content: String) -> String? {
        let sorted = edits.sorted { lhs, rhs in
            if lhs.range.start.line != rhs.range.start.line {
                return lhs.range.start.line > rhs.range.start.line
            }
            return lhs.range.start.character > rhs.range.start.character
        }

        var result = content
        for edit in sorted {
            guard let nsRange = nsRange(from: edit.range, in: result),
                  let swiftRange = Range(nsRange, in: result) else {
                return nil
            }
            result.replaceSubrange(swiftRange, with: edit.newText)
        }
        return result
    }

    private static func nsRange(from lspRange: LSPRange, in content: String) -> NSRange? {
        guard let start = utf16Offset(for: lspRange.start, in: content),
              let end = utf16Offset(for: lspRange.end, in: content),
              end >= start else {
            return nil
        }
        return NSRange(location: start, length: end - start)
    }

    private static func utf16Offset(for position: Position, in content: String) -> Int? {
        var line = 0
        var utf16Offset = 0
        var lineStartOffset = 0

        for scalar in content.unicodeScalars {
            if line == position.line {
                break
            }
            utf16Offset += scalar.utf16.count
            if scalar == "\n" {
                line += 1
                lineStartOffset = utf16Offset
            }
        }

        guard line == position.line else { return nil }
        return min(lineStartOffset + position.character, content.utf16.count)
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

    private func endMultiCursorSearchSession() {
        multiCursorSearchSession = nil
    }

    private func selectionText(for selection: MultiCursorSelection) -> String? {
        guard let content else { return nil }
        let text = content.string as NSString
        let range = nsRange(from: selection)
        guard range.location != NSNotFound, NSMaxRange(range) <= text.length else { return nil }
        return text.substring(with: range)
    }

    private func normalizedRange(_ range: NSRange, in text: NSString) -> NSRange {
        guard range.location != NSNotFound else { return NSRange(location: NSNotFound, length: 0) }
        let location = min(max(range.location, 0), text.length)
        let length = min(max(range.length, 0), max(0, text.length - location))
        return NSRange(location: location, length: length)
    }

    private func resolvedBaseSelection(from range: NSRange, in text: NSString) -> MultiCursorSelection? {
        if range.length > 0 {
            return MultiCursorSelection(location: range.location, length: range.length)
        }

        guard let wordRange = wordRange(at: range.location, in: text) else {
            return nil
        }
        guard wordRange.length > 0 else { return nil }
        return MultiCursorSelection(location: wordRange.location, length: wordRange.length)
    }

    private func wordRange(at location: Int, in text: NSString) -> NSRange? {
        guard text.length > 0 else { return nil }
        let clampedLocation = min(max(location, 0), text.length)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))

        func isWordCharacter(at index: Int) -> Bool {
            guard index >= 0, index < text.length else { return false }
            let scalar = text.substring(with: NSRange(location: index, length: 1)).unicodeScalars.first
            return scalar.map { allowed.contains($0) } ?? false
        }

        var pivot = clampedLocation
        if pivot == text.length {
            pivot = max(text.length - 1, 0)
        }
        if !isWordCharacter(at: pivot), clampedLocation > 0, isWordCharacter(at: clampedLocation - 1) {
            pivot = clampedLocation - 1
        }
        guard isWordCharacter(at: pivot) else { return nil }

        var start = pivot
        var end = pivot
        while start > 0, isWordCharacter(at: start - 1) {
            start -= 1
        }
        while end + 1 < text.length, isWordCharacter(at: end + 1) {
            end += 1
        }
        return NSRange(location: start, length: end - start + 1)
    }

    private func ranges(of needle: String, in text: NSString) -> [MultiCursorSelection] {
        guard !needle.isEmpty else { return [] }
        var result: [MultiCursorSelection] = []
        var searchLocation = 0
        let needleLength = (needle as NSString).length
        let shouldMatchWholeWord = isWholeWordSelection(needle)

        while searchLocation <= text.length - needleLength {
            let searchRange = NSRange(location: searchLocation, length: text.length - searchLocation)
            let found = text.range(of: needle, options: [], range: searchRange)
            guard found.location != NSNotFound else { break }

            let selection = MultiCursorSelection(location: found.location, length: found.length)
            if !shouldMatchWholeWord || isWholeWordMatch(selection, in: text) {
                result.append(selection)
            }

            searchLocation = found.location + max(found.length, 1)
        }

        return result
    }

    private func isWholeWordSelection(_ text: String) -> Bool {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        return text.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private func isWholeWordMatch(_ selection: MultiCursorSelection, in text: NSString) -> Bool {
        let lowerIndex = selection.location - 1
        let upperIndex = selection.upperBound
        return !isWordCharacter(at: lowerIndex, in: text) && !isWordCharacter(at: upperIndex, in: text)
    }

    private func isWordCharacter(at index: Int, in text: NSString) -> Bool {
        guard index >= 0, index < text.length else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        let scalar = text.substring(with: NSRange(location: index, length: 1)).unicodeScalars.first
        return scalar.map { allowed.contains($0) } ?? false
    }

    private func nsRange(from selection: MultiCursorSelection) -> NSRange {
        NSRange(location: selection.location, length: selection.length)
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
