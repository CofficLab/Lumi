import SwiftUI
@preconcurrency import CodeEditSourceEditor
import CodeEditTextView
import CodeEditLanguages
import LanguageServerProtocol
import Combine
import os

/// 编辑器 LSP 协调器
/// 负责将 LSP 服务与 CodeEditSourceEditor 集成
@MainActor
class LSPCoordinator: ObservableObject {
    
    private let logger = Logger(subsystem: "com.coffic.lumi", category: "lsp.coordinator")
    private let lspService = LSPService.shared
    
    /// 当前文件 URI
    var fileURI: String?
    /// 语言标识
    var languageId: String = "swift"
    /// 文档版本计数器
    private var version = 0
    
    // MARK: - Lifecycle
    
    func setProjectRootPath(_ path: String?) {
        lspService.setProjectRootPath(path)
    }
    
    /// 打开文件时调用
    func openFile(uri: String, languageId: String, content: String) async {
        self.fileURI = uri
        self.languageId = languageId
        self.version = 0
        
        await lspService.openDocument(uri: uri, languageId: languageId, text: content)
        logger.info("LSP: File opened \(uri)")
    }
    
    /// 关闭文件时调用
    func closeFile() {
        guard let uri = fileURI else { return }
        lspService.closeDocument(uri: uri)
        fileURI = nil
        logger.info("LSP: File closed")
    }
    
    /// 文档内容变更
    func updateDocumentSnapshot(_ content: String) {
        guard let uri = fileURI else { return }
        lspService.updateDocumentSnapshot(uri: uri, text: content)
    }
    
    /// 文档内容增量变更
    func contentDidChange(range: LSPRange, text: String) {
        guard let uri = fileURI else { return }
        version += 1
        lspService.documentDidChange(uri: uri, range: range, text: text)
    }
    
    /// 文档内容被整段替换（外部修改等）
    func replaceDocument(_ content: String) {
        guard let uri = fileURI else { return }
        version += 1
        lspService.replaceDocument(uri: uri, text: content)
    }
    
    // MARK: - LSP Features
    
    /// 请求代码补全
    func requestCompletion(line: Int, character: Int) async -> [CompletionItem] {
        guard let uri = fileURI else { return [] }
        return await lspService.requestCompletion(uri: uri, line: line, character: character)
    }
    
    /// 请求悬停提示（返回纯文本，已废弃）
    func requestHover(line: Int, character: Int) async -> String? {
        guard let uri = fileURI else { return nil }
        return await lspService.requestHover(uri: uri, line: line, character: character)
    }

    /// 请求悬停提示（返回原始 Hover 对象，支持 Markdown 解析）
    func requestHoverRaw(line: Int, character: Int) async -> Hover? {
        guard let uri = fileURI else { return nil }
        return await lspService.requestHoverRaw(uri: uri, line: line, character: character)
    }
    
    /// 请求定义位置
    func requestDefinition(line: Int, character: Int) async -> Location? {
        guard let uri = fileURI else { return nil }
        return await lspService.requestDefinition(uri: uri, line: line, character: character)
    }

    /// 请求引用
    func requestReferences(line: Int, character: Int) async -> [Location] {
        guard let uri = fileURI else { return [] }
        return await lspService.requestReferences(uri: uri, line: line, character: character)
    }

    /// 请求文档符号
    func requestDocumentSymbols() async -> [DocumentSymbol] {
        guard let uri = fileURI else { return [] }
        return await lspService.requestDocumentSymbols(uri: uri)
    }

    /// 请求重命名
    func requestRename(line: Int, character: Int, newName: String) async -> WorkspaceEdit? {
        guard let uri = fileURI else { return nil }
        return await lspService.requestRename(uri: uri, line: line, character: character, newName: newName)
    }

    /// 请求格式化
    func requestFormatting(tabSize: Int, insertSpaces: Bool) async -> [TextEdit]? {
        guard let uri = fileURI else { return nil }
        return await lspService.requestFormatting(uri: uri, tabSize: tabSize, insertSpaces: insertSpaces)
    }
    
    /// 请求签名帮助
    func requestSignatureHelp(line: Int, character: Int) async -> SignatureHelp? {
        guard let uri = fileURI else { return nil }
        return await lspService.requestSignatureHelp(uri: uri, line: line, character: character)
    }
    
    /// 请求内联提示
    func requestInlayHint(startLine: Int, startCharacter: Int, endLine: Int, endCharacter: Int) async -> [InlayHint]? {
        guard let uri = fileURI else { return nil }
        return await lspService.requestInlayHint(uri: uri, startLine: startLine, startCharacter: startCharacter, endLine: endLine, endCharacter: endCharacter)
    }
    
    /// 请求文档高亮
    func requestDocumentHighlight(line: Int, character: Int) async -> [DocumentHighlight] {
        guard let uri = fileURI else { return [] }
        return await lspService.requestDocumentHighlight(uri: uri, line: line, character: character)
    }
    
    /// 请求代码动作
    func requestCodeAction(range: LSPRange, diagnostics: [Diagnostic], triggerKinds: [CodeActionKind]? = nil) async -> [CodeAction] {
        guard let uri = fileURI else { return [] }
        return await lspService.requestCodeAction(uri: uri, range: range, diagnostics: diagnostics, triggerKinds: triggerKinds)
    }

    /// 请求声明位置
    func requestDeclaration(line: Int, character: Int) async -> Location? {
        guard let uri = fileURI else { return nil }
        let response = await lspService.requestDeclaration(uri: uri, line: line, character: character)
        return lspService.parseLocationResponse(response)
    }

    /// 请求类型定义位置
    func requestTypeDefinition(line: Int, character: Int) async -> Location? {
        guard let uri = fileURI else { return nil }
        let response = await lspService.requestTypeDefinition(uri: uri, line: line, character: character)
        return lspService.parseLocationResponse(response)
    }

    /// 请求实现位置
    func requestImplementation(line: Int, character: Int) async -> Location? {
        guard let uri = fileURI else { return nil }
        let response = await lspService.requestImplementation(uri: uri, line: line, character: character)
        return lspService.parseLocationResponse(response)
    }

    func completionTriggerCharacters() -> Set<String> {
        lspService.completionTriggerCharacters
    }
    
    // MARK: - New LSP Features
    
    /// 请求折叠范围
    func requestFoldingRange() async -> [FoldingRange] {
        guard let uri = fileURI else { return [] }
        return await lspService.requestFoldingRange(uri: uri)
    }
    
    /// 请求选择范围
    func requestSelectionRange(line: Int, character: Int) async -> [SelectionRange] {
        guard let uri = fileURI else { return [] }
        return await lspService.requestSelectionRange(uri: uri, line: line, character: character)
    }
    
    /// 请求文档链接
    func requestDocumentLinks() async -> [DocumentLink] {
        guard let uri = fileURI else { return [] }
        return await lspService.requestDocumentLinks(uri: uri)
    }
    
    /// 请求文档颜色
    func requestDocumentColors() async -> [ColorInformation] {
        guard let uri = fileURI else { return [] }
        return await lspService.requestDocumentColors(uri: uri)
    }
    
    /// 请求调用层级
    func requestCallHierarchy(line: Int, character: Int) async {
        guard let uri = fileURI else { return }
        await lspService.requestCallHierarchyPrepare(uri: uri, line: line, character: character)
    }
    
    /// 请求工作区符号
    func requestWorkspaceSymbols(query: String) async -> WorkspaceSymbolResponse {
        return await lspService.requestWorkspaceSymbols(query: query)
    }
    
    /// 执行 LSP 自定义命令
    func executeCommand(command: String, arguments: [LanguageServerProtocol.LSPAny]? = nil) async -> LanguageServerProtocol.LSPAny? {
        return await lspService.executeCommand(command: command, arguments: arguments)
    }
}

// MARK: - Diagnostics Manager

/// LSP 诊断管理器
/// 使用 LanguageServerProtocol 的 Diagnostic 类型
@MainActor
final class DiagnosticsManager: ObservableObject {
    
    private let lspService = LSPService.shared
    
    /// 当前诊断列表（使用 LSP 标准类型）
    @Published var diagnostics: [Diagnostic] = []
    /// 错误计数
    @Published var errorCount: Int = 0
    /// 警告计数
    @Published var warningCount: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        lspService.$currentDiagnostics
            .sink { [weak self] newDiagnostics in
                self?.diagnostics = newDiagnostics
                self?.updateCounts()
            }
            .store(in: &cancellables)
    }
    
    private func updateCounts() {
        errorCount = diagnostics.filter { $0.severity == .error }.count
        warningCount = diagnostics.filter { $0.severity == .warning }.count
    }
    
    /// 获取指定行的诊断
    func diagnosticsForLine(_ line: Int) -> [Diagnostic] {
        diagnostics.filter { diag in
            diag.range.start.line <= line && diag.range.end.line >= line
        }
    }
    
    /// 检查指定位置是否有错误
    func hasErrorAt(line: Int, character: Int) -> Bool {
        diagnostics.contains { diag in
            diag.severity == .error &&
            diag.range.start.line <= line &&
            diag.range.end.line >= line &&
            (diag.range.start.line != line || diag.range.start.character <= character) &&
            (diag.range.end.line != line || diag.range.end.character >= character)
        }
    }
}

// MARK: - Code Completion Provider

/// LSP 代码补全提供者
@MainActor
final class CompletionProvider: ObservableObject {
    
    private let lspService = LSPService.shared
    
    @Published var completionItems: [CompletionItem] = []
    @Published var isLoading: Bool = false
    
    /// 补全类型映射
    static func completionKindString(_ kind: CompletionItemKind?) -> String {
        switch kind {
        case .text: return "Text"
        case .method: return "Method"
        case .function: return "Function"
        case .constructor: return "Constructor"
        case .field: return "Field"
        case .variable: return "Variable"
        case .class: return "Class"
        case .interface: return "Interface"
        case .module: return "Module"
        case .property: return "Property"
        case .unit: return "Unit"
        case .value: return "Value"
        case .enum: return "Enum"
        case .keyword: return "Keyword"
        case .snippet: return "Snippet"
        case .color: return "Color"
        case .file: return "File"
        case .reference: return "Reference"
        case .folder: return "Folder"
        case .enumMember: return "EnumMember"
        case .constant: return "Constant"
        case .struct: return "Struct"
        case .event: return "Event"
        case .operator: return "Operator"
        case .typeParameter: return "TypeParameter"
        default: return "Unknown"
        }
    }
    
    /// 补全图标
    static func completionIcon(_ kind: CompletionItemKind?) -> String {
        switch kind {
        case .method, .constructor: return "square.and.arrow.up"
        case .function: return "function"
        case .field, .property: return "textformat"
        case .variable: return "variable"
        case .class: return "square.3.layers.3d"
        case .interface: return "square.on.square"
        case .module: return "cube.box"
        case .enum: return "circle.grid.2x2"
        case .keyword: return "rectangle.3.group"
        case .snippet: return "puzzlepiece.extension"
        case .file: return "doc"
        case .struct: return "rectangle.stack"
        default: return "text.bubble"
        }
    }
}

// MARK: - Status Bar Item

struct LSPDiagnosticStatusBarItem: View {
    
    @StateObject private var diagnosticsManager = DiagnosticsManager()
    
    var body: some View {
        HStack(spacing: 12) {
            if diagnosticsManager.errorCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("\(diagnosticsManager.errorCount)")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            
            if diagnosticsManager.warningCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("\(diagnosticsManager.warningCount)")
                        .font(.system(size: 11, weight: .medium))
                }
            }
        }
        .opacity(diagnosticsManager.errorCount > 0 || diagnosticsManager.warningCount > 0 ? 1 : 0)
    }
}

// MARK: - Hover Tooltip View

/// 悬停提示浮层
struct LSPHoverTooltip: View {
    
    let content: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Text(content)
            .font(.system(size: 12, design: .monospaced))
            .padding(8)
            .frame(maxWidth: 400, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(colorScheme == .dark ? Color(nsColor: .controlBackgroundColor) : Color.white)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
            )
    }
}

// MARK: - Semantic Tokens

struct SemanticTokenMap: Sendable {
    private let tokenTypeMap: [CaptureName?]
    private let modifierMap: [CaptureModifier?]
    
    init(semanticCapability: TwoTypeOption<SemanticTokensOptions, SemanticTokensRegistrationOptions>?) {
        guard let semanticCapability else {
            tokenTypeMap = []
            modifierMap = []
            return
        }
        
        let legend: SemanticTokensLegend
        switch semanticCapability {
        case .optionA(let options):
            legend = options.legend
        case .optionB(let options):
            legend = options.legend
        }
        
        tokenTypeMap = legend.tokenTypes.map { CaptureName.fromString($0) }
        modifierMap = legend.tokenModifiers.map { CaptureModifier.fromString($0) }
    }
    
    func decode(tokens: [SemanticToken], content: String) -> [HighlightRange] {
        tokens.compactMap { token in
            guard let range = Self.nsRange(
                line: Int(token.line),
                character: Int(token.char),
                length: Int(token.length),
                in: content
            ) else {
                return nil
            }
            
            let typeIndex = Int(token.type)
            let capture = tokenTypeMap.indices.contains(typeIndex) ? tokenTypeMap[typeIndex] : nil
            let modifiers = decodeModifier(token.modifiers)
            
            return HighlightRange(range: range, capture: capture, modifiers: modifiers)
        }
    }
    
    private func decodeModifier(_ raw: UInt32) -> CaptureModifierSet {
        var result: CaptureModifierSet = []
        var raw = raw
        while raw > 0 {
            let idx = raw.trailingZeroBitCount
            raw &= ~(1 << idx)
            guard let modifier = modifierMap.indices.contains(idx) ? modifierMap[idx] : nil else { continue }
            result.insert(modifier)
        }
        return result
    }
    
    static func nsRange(line: Int, character: Int, length: Int, in content: String) -> NSRange? {
        guard line >= 0, character >= 0, length >= 0 else { return nil }
        guard let start = utf16Offset(line: line, character: character, in: content) else { return nil }
        let end = start + length
        guard end <= content.utf16.count else { return nil }
        return NSRange(location: start, length: length)
    }
    
    private static func utf16Offset(line: Int, character: Int, in content: String) -> Int? {
        var currentLine = 0
        var offset = 0
        var lineStartOffset = 0
        
        for scalar in content.unicodeScalars {
            if currentLine == line {
                break
            }
            offset += scalar.utf16.count
            if scalar == "\n" {
                currentLine += 1
                lineStartOffset = offset
            }
        }
        
        guard currentLine == line else { return nil }
        return min(lineStartOffset + character, content.utf16.count)
    }
}

private struct SemanticTokenRange {
    let line: UInt32
    let char: UInt32
    let length: UInt32
}

private final class SemanticTokenStorage {
    private struct CurrentState {
        let resultId: String?
        let tokenData: [UInt32]
        let tokens: [SemanticToken]
    }
    
    private var state: CurrentState?
    
    var lastResultId: String? { state?.resultId }
    var hasReceivedData: Bool { state != nil }
    var tokens: [SemanticToken] { state?.tokens ?? [] }
    
    func setData(_ data: borrowing SemanticTokens) {
        state = CurrentState(resultId: data.resultId, tokenData: data.data, tokens: data.decode())
    }
    
    func applyDelta(_ deltas: SemanticTokensDelta) -> [SemanticTokenRange] {
        guard var tokenData = state?.tokenData else { return [] }
        var invalidatedSet: [SemanticTokenRange] = []
        
        for edit in deltas.edits.sorted(by: { $0.start > $1.start }) {
            invalidatedSet.append(
                contentsOf: invalidatedRanges(start: edit.start, length: edit.deleteCount, data: tokenData[...])
            )
            
            if edit.deleteCount > 0 {
                tokenData.replaceSubrange(Int(edit.start)..<Int(edit.start + edit.deleteCount), with: edit.data ?? [])
            } else {
                tokenData.insert(contentsOf: edit.data ?? [], at: Int(edit.start))
            }
            
            if let inserted = edit.data, !inserted.isEmpty {
                invalidatedSet.append(
                    contentsOf: invalidatedRanges(start: edit.start, length: UInt(inserted.count), data: tokenData[...])
                )
            }
        }
        
        let decodedTokens = SemanticTokens(data: tokenData).decode()
        state = CurrentState(resultId: deltas.resultId, tokenData: tokenData, tokens: decodedTokens)
        return invalidatedSet
    }
    
    private func invalidatedRanges(start: UInt, length: UInt, data: ArraySlice<UInt32>) -> [SemanticTokenRange] {
        guard length > 0, !data.isEmpty else { return [] }
        
        var ranges: [SemanticTokenRange] = []
        var idx = Int(start - (start % 5))
        let end = Int(start + length)
        
        while idx + 2 < data.count && idx < end {
            ranges.append(
                SemanticTokenRange(
                    line: data[idx],
                    char: data[idx + 1],
                    length: data[idx + 2]
                )
            )
            idx += 5
        }
        return ranges
    }
}

@MainActor
final class SemanticTokenHighlightProvider: HighlightProviding {
    private let lspService = LSPService.shared
    private let uriProvider: () -> String?
    private var textView: TextView?
    private var highlights: [HighlightRange] = []
    private var storage = SemanticTokenStorage()
    private var isRefreshing = false
    private var needsRefreshAgain = false
    private var pendingEditCallback: ((Result<IndexSet, Error>) -> Void)?
    private var pendingFallbackRange: NSRange?
    private var viewportRefreshTask: Task<Void, Never>?
    private var scrollBoundsObserver: NSObjectProtocol?
    private var scrollFrameObserver: NSObjectProtocol?
    
    init(uriProvider: @escaping () -> String?) {
        self.uriProvider = uriProvider
    }
    
    func setUp(textView: TextView, codeLanguage: CodeLanguage) {
        self.textView = textView
        installViewportObservers(for: textView)
        refreshSemanticTokens()
    }
    
    func scheduleViewportRefresh() {
        viewportRefreshTask?.cancel()
        viewportRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.refreshSemanticTokens()
            }
        }
    }
    
    func applyEdit(
        textView: TextView,
        range: NSRange,
        delta: Int,
        completion: @escaping @MainActor (Result<IndexSet, Error>) -> Void
    ) {
        if let previous = pendingEditCallback {
            previous(.success(IndexSet()))
        }
        pendingEditCallback = completion
        pendingFallbackRange = expandedInvalidationRange(
            from: range,
            delta: delta,
            documentLength: textView.documentRange.length
        )
        refreshSemanticTokens()
    }
    
    func queryHighlightsFor(
        textView: TextView,
        range: NSRange,
        completion: @escaping @MainActor (Result<[HighlightRange], Error>) -> Void
    ) {
        let query = range
        let result = highlights.compactMap { item -> HighlightRange? in
            let intersection = NSIntersectionRange(item.range, query)
            guard intersection.length > 0 else { return nil }
            return HighlightRange(range: intersection, capture: item.capture, modifiers: item.modifiers)
        }
        completion(.success(result))
    }
    
    private func refreshSemanticTokens() {
        guard !isRefreshing else {
            needsRefreshAgain = true
            return
        }
        guard let uri = uriProvider(), let textView else { return }
        isRefreshing = true
        
        Task { [weak self] in
            guard let self else { return }
            defer {
                Task { @MainActor in
                    self.isRefreshing = false
                    if self.needsRefreshAgain {
                        self.needsRefreshAgain = false
                        self.refreshSemanticTokens()
                    }
                }
            }
            
            guard let map = await MainActor.run(body: { self.lspService.currentSemanticTokenMap }) else {
                return
            }
            
            let invalidatedRanges: [NSRange]
            
            if let previousResultId = storage.lastResultId,
               let deltaResponse = await lspService.requestSemanticTokensDelta(uri: uri, previousResultId: previousResultId) {
                switch deltaResponse {
                case .optionA(let full):
                    storage.setData(full)
                    invalidatedRanges = [textView.documentRange]
                case .optionB(let delta):
                    let changed = storage.applyDelta(delta)
                    invalidatedRanges = changed.compactMap {
                        SemanticTokenMap.nsRange(
                            line: Int($0.line),
                            character: Int($0.char),
                            length: Int($0.length),
                            in: textView.string
                        )
                    }
                case .none:
                    if let full = await lspService.requestSemanticTokens(uri: uri) {
                        storage.setData(full)
                        invalidatedRanges = [textView.documentRange]
                    } else {
                        invalidatedRanges = []
                    }
                }
            } else if let full = await lspService.requestSemanticTokens(uri: uri) {
                storage.setData(full)
                invalidatedRanges = [textView.documentRange]
            } else {
                return
            }
            
            let decoded = map.decode(tokens: storage.tokens, content: textView.string)
            await MainActor.run {
                self.highlights = decoded
                self.completePendingEdit(using: invalidatedRanges, documentRange: textView.documentRange)
            }
        }
    }
    
    private func expandedInvalidationRange(from range: NSRange, delta: Int, documentLength: Int) -> NSRange {
        let padding = 128
        let start = max(0, range.location - padding)
        let length = max(0, range.length + max(0, delta) + padding * 2)
        let end = min(documentLength, start + length)
        return NSRange(location: start, length: max(0, end - start))
    }
    
    private func completePendingEdit(using ranges: [NSRange], documentRange: NSRange) {
        guard let callback = pendingEditCallback else { return }
        pendingEditCallback = nil
        
        if !ranges.isEmpty {
            callback(.success(IndexSet(ranges: ranges)))
            pendingFallbackRange = nil
            return
        }
        
        if let fallback = pendingFallbackRange, fallback.length > 0 {
            callback(.success(IndexSet(integersIn: fallback)))
            pendingFallbackRange = nil
            return
        }
        
        callback(.success(IndexSet(integersIn: documentRange)))
    }
    
    private func installViewportObservers(for textView: TextView) {
        scrollBoundsObserver.map(NotificationCenter.default.removeObserver)
        scrollFrameObserver.map(NotificationCenter.default.removeObserver)
        scrollBoundsObserver = nil
        scrollFrameObserver = nil
        
        guard let scrollView = textView.enclosingScrollView else { return }
        let clipView = scrollView.contentView
        
        scrollBoundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.scheduleViewportRefresh()
            }
        }
        
        scrollFrameObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.scheduleViewportRefresh()
            }
        }
    }
    
    private func removeViewportObservers() {
        if let observer = scrollBoundsObserver {
            NotificationCenter.default.removeObserver(observer)
            scrollBoundsObserver = nil
        }
        if let observer = scrollFrameObserver {
            NotificationCenter.default.removeObserver(observer)
            scrollFrameObserver = nil
        }
    }
    
    deinit {
        viewportRefreshTask?.cancel()
    }
}
