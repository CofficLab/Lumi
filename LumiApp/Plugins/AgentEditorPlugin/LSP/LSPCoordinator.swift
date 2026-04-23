import SwiftUI
@preconcurrency import CodeEditSourceEditor
import CodeEditTextView
import CodeEditLanguages
import LanguageServerProtocol
import Combine
import os
import MagicKit

/// 编辑器 LSP 协调器
/// 负责将 LSP 服务与 CodeEditSourceEditor 集成
@MainActor
class LSPCoordinator: ObservableObject, SuperLog, EditorLSPClient {
    nonisolated static let emoji = "😊 "
    nonisolated static let verbose = true
    
    private let logger = Logger(subsystem: "com.coffic.lumi", category: "lsp.coordinator")
    private let lspService: LSPService
    
    /// LSP 请求防抖器 — 避免快速连续请求导致主线程阻塞
    private let debouncer = LSPDebouncer()

    /// 当前文件 URI
    var fileURI: String?
    /// 语言标识
    var languageId: String = "swift"
    /// 文档版本计数器
    private var version = 0

    init(lspService: LSPService = .shared) {
        self.lspService = lspService
    }
    
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
        logger.info("\(Self.t)LSP: 已打开文件 \(uri)")
    }
    
    /// 关闭文件时调用
    func closeFile() {
        guard let uri = fileURI else { return }
        lspService.closeDocument(uri: uri)
        fileURI = nil
        logger.info("\(Self.t)LSP: 已关闭文件")
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
    
    /// 请求代码补全（防抖版 — 50ms延迟，新请求取消旧请求）
    func requestCompletionDebounced(line: Int, character: Int) async -> [CompletionItem] {
        guard let uri = fileURI else { return [] }
        let key = "completion_\(uri)_\(line)_\(character)"
        return await debouncer.debounce(key: key, delay: 50_000_000) { [weak self] in
            guard let self else { return [] }
            return await self.lspService.requestCompletion(uri: uri, line: line, character: character)
        } ?? []
    }

    /// 请求代码补全（直接版）
    func requestCompletion(line: Int, character: Int) async -> [CompletionItem] {
        guard let uri = fileURI else { return [] }
        return await lspService.requestCompletion(uri: uri, line: line, character: character)
    }
    
    /// 请求悬停提示（防抖版 — 200ms延迟，鼠标需静止才请求）
    func requestHoverRawDebounced(line: Int, character: Int) async -> Hover? {
        guard let uri = fileURI else { return nil }
        let key = "hover_\(uri)_\(line)_\(character)"
        return await debouncer.debounce(key: key, delay: 200_000_000) { [weak self] in
            guard let self else { return nil }
            return await self.lspService.requestHoverRaw(uri: uri, line: line, character: character)
        }
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
    
    /// 请求文档高亮（节流版 — 250ms最小间隔）
    func requestDocumentHighlightThrottled(line: Int, character: Int) async -> [DocumentHighlight] {
        guard let uri = fileURI else { return [] }
        let key = "highlight_\(uri)"
        return await debouncer.throttle(key: key, interval: 250_000_000) { [weak self] in
            guard let self else { return [] }
            return await self.lspService.requestDocumentHighlight(uri: uri, line: line, character: character)
        } ?? []
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
    
    /// 请求代码动作（防抖版 — 300ms延迟，与诊断同步）
    func requestCodeActionDebounced(range: LSPRange, diagnostics: [Diagnostic], triggerKinds: [CodeActionKind]? = nil) async -> [CodeAction] {
        guard let uri = fileURI else { return [] }
        let key = "codeaction_\(uri)_\(range.start.line)_\(range.start.character)"
        return await debouncer.debounce(key: key, delay: 300_000_000) { [weak self] in
            guard let self else { return [] }
            return await self.lspService.requestCodeAction(uri: uri, range: range, diagnostics: diagnostics, triggerKinds: triggerKinds)
        } ?? []
    }

    /// 请求签名帮助（防抖版 — 150ms延迟）
    func requestSignatureHelpDebounced(line: Int, character: Int) async -> SignatureHelp? {
        guard let uri = fileURI else { return nil }
        let key = "signature_\(uri)_\(line)_\(character)"
        return await debouncer.debounce(key: key, delay: 150_000_000) { [weak self] in
            guard let self else { return nil }
            return await self.lspService.requestSignatureHelp(uri: uri, line: line, character: character)
        }
    }

    /// 请求内联提示（节流版 — 500ms间隔）
    func requestInlayHintThrottled(startLine: Int, startCharacter: Int, endLine: Int, endCharacter: Int) async -> [InlayHint]? {
        guard let uri = fileURI else { return nil }
        let key = "inlayhint_\(uri)"
        return await debouncer.throttle(key: key, interval: 500_000_000) { [weak self] in
            guard let self else { return nil }
            return await self.lspService.requestInlayHint(uri: uri, startLine: startLine, startCharacter: startCharacter, endLine: endLine, endCharacter: endCharacter)
        }
    }

    /// 请求折叠范围（防抖版 — 1s延迟，打开文件时请求）
    func requestFoldingRangeDebounced() async -> [FoldingRange] {
        guard let uri = fileURI else { return [] }
        let key = "folding_\(uri)"
        return await debouncer.debounce(key: key, delay: 1_000_000_000) { [weak self] in
            guard let self else { return [] }
            return await self.lspService.requestFoldingRange(uri: uri)
        } ?? []
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
    
    private let lspService: LSPService
    
    /// 当前诊断列表（使用 LSP 标准类型）
    @Published var diagnostics: [Diagnostic] = []
    /// 错误计数
    @Published var errorCount: Int = 0
    /// 警告计数
    @Published var warningCount: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    init(lspService: LSPService = .shared) {
        self.lspService = lspService
        lspService.$currentDiagnostics
            .sink { [weak self] newDiagnostics in
                self?.diagnostics = newDiagnostics
                self?.updateCounts()
            }
            .store(in: &cancellables)
    }
    
    private func updateCounts() {
        // 单次遍历替代两次 filter
        var errors = 0, warnings = 0
        for diag in diagnostics {
            if diag.severity == .error { errors += 1 }
            else if diag.severity == .warning { warnings += 1 }
        }
        errorCount = errors
        warningCount = warnings
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
    
    private let lspService: LSPService
    
    @Published var completionItems: [CompletionItem] = []
    @Published var isLoading: Bool = false

    init(lspService: LSPService = .shared) {
        self.lspService = lspService
    }
    
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
    fileprivate let tokenTypeMap: [CaptureName?]
    fileprivate let modifierMap: [CaptureModifier?]
    
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
    
    /// 使用 LineOffsetTable 优化的快速解码（O(n) + O(m)，替代 O(n×m)）
    func decodeWithTable(tokens: [SemanticToken], table: LineOffsetTable) -> [HighlightRange] {
        tokens.compactMap { token in
            let line = Int(token.line)
            let char = Int(token.char)
            let length = Int(token.length)
            guard let start = table.utf16Offset(line: line, character: char) else { return nil }
            let end = start + length
            guard end <= table.totalUTF16Length else { return nil }

            let typeIndex = Int(token.type)
            let capture = tokenTypeMap.indices.contains(typeIndex) ? tokenTypeMap[typeIndex] : nil
            let modifiers = decodeModifier(token.modifiers)

            return HighlightRange(range: NSRange(location: start, length: length), capture: capture, modifiers: modifiers)
        }
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
    
    /// 在后台线程解码语义 Token（P1.6 优化）
    /// 纯计算操作，不阻塞主线程
    /// 使用 DispatchQueue.global 执行解码，避免 Sendable 兼容性问题
    func decodeInBackground(tokens: [SemanticToken], content: String) async -> [HighlightRange] {
        let tokenTypeMap = self.tokenTypeMap
        let modifierMap = self.modifierMap
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = tokens.compactMap { token -> HighlightRange? in
                    guard let range = SemanticTokenMap.nsRange(
                        line: Int(token.line),
                        character: Int(token.char),
                        length: Int(token.length),
                        in: content
                    ) else {
                        return nil
                    }
                    
                    let typeIndex = Int(token.type)
                    let capture = tokenTypeMap.indices.contains(typeIndex) ? tokenTypeMap[typeIndex] : nil
                    var modifiers: CaptureModifierSet = []
                    var raw = token.modifiers
                    while raw > 0 {
                        let idx = raw.trailingZeroBitCount
                        raw &= ~(1 << idx)
                        if modifierMap.indices.contains(idx), let modifier = modifierMap[idx] {
                            modifiers.insert(modifier)
                        }
                    }
                    
                    return HighlightRange(range: range, capture: capture, modifiers: modifiers)
                }
                continuation.resume(returning: result)
            }
        }
    }
    
    /// 同步解码语义 Token（在已隔离的后台上下文中使用）
    func decodeSync(tokens: [SemanticToken], content: String) -> [HighlightRange] {
        tokens.compactMap { token -> HighlightRange? in
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
            var modifiers: CaptureModifierSet = []
            var raw = token.modifiers
            while raw > 0 {
                let idx = raw.trailingZeroBitCount
                raw &= ~(1 << idx)
                if modifierMap.indices.contains(idx), let modifier = modifierMap[idx] {
                    modifiers.insert(modifier)
                }
            }
            
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
    private let lspService: LSPService
    private let uriProvider: () -> String?
    private var textView: TextView?
    private var highlights: [HighlightRange] = []
    private var storage = SemanticTokenStorage()
    private var isRefreshing = false
    private var needsRefreshAgain = false
    private var pendingEditCallback: ((Result<IndexSet, Error>) -> Void)?
    private var pendingFallbackRange: NSRange?
    private var viewportRefreshTask: Task<Void, Never>?
    /// applyEdit 防抖任务：快速连续按键时延迟 refresh，避免每次按键都触发 LSP 请求
    private var editDebounceTask: Task<Void, Never>?
    private var scrollBoundsObserver: NSObjectProtocol?
    private var scrollFrameObserver: NSObjectProtocol?
    
    init(
        lspService: LSPService = .shared,
        uriProvider: @escaping () -> String?
    ) {
        self.lspService = lspService
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
        // ✅ 防抖：先立即用 fallback range 回调编辑器（保证文本不丢），
        // 然后延迟 80ms 再请求 LSP refresh。连续快速按键时只触发最后一次。
        editDebounceTask?.cancel()
        editDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled else { return }
            self?.refreshSemanticTokens()
        }
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
                    // 使用 LineOffsetTable 快速计算 invalidated ranges
                    let deltaTable = LineOffsetTable(content: textView.string)
                    invalidatedRanges = changed.compactMap { token in
                        guard let start = deltaTable.utf16Offset(line: Int(token.line), character: Int(token.char)) else { return nil }
                        let length = Int(token.length)
                        guard start + length <= deltaTable.totalUTF16Length else { return nil }
                        return NSRange(location: start, length: length)
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
            
            // Token 解码优化：使用 LineOffsetTable 将 O(n×m) 降至 O(n)+m
            let localTokens = self.storage.tokens
            let localContent = textView.string
            let table = LineOffsetTable(content: localContent)
            let decoded = map.decodeWithTable(tokens: localTokens, table: table)
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
        editDebounceTask?.cancel()
    }
}
