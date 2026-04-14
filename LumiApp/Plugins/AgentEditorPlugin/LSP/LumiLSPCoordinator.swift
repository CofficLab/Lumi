import SwiftUI
import CodeEditSourceEditor
import CodeEditTextView
import LanguageServerProtocol
import Combine
import os

/// 编辑器 LSP 协调器
/// 负责将 LSP 服务与 CodeEditSourceEditor 集成
@MainActor
class LumiLSPCoordinator: ObservableObject {
    
    private let logger = Logger(subsystem: "com.coffic.lumi", category: "lsp.coordinator")
    private let lspService = LumiLSPService.shared
    
    /// 当前文件 URI
    var fileURI: String?
    /// 语言标识
    var languageId: String = "swift"
    /// 文档版本计数器
    private var version = 0
    
    // MARK: - Lifecycle
    
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
    func contentDidChange(_ content: String) {
        guard let uri = fileURI else { return }
        version += 1
        lspService.documentDidChange(uri: uri, text: content)
    }
    
    // MARK: - LSP Features
    
    /// 请求代码补全
    func requestCompletion(line: Int, character: Int) async {
        guard let uri = fileURI else { return }
        await lspService.requestCompletion(uri: uri, line: line, character: character)
    }
    
    /// 请求悬停提示
    func requestHover(line: Int, character: Int) async {
        guard let uri = fileURI else { return }
        await lspService.requestHover(uri: uri, line: line, character: character)
    }
    
    /// 请求定义位置
    func requestDefinition(line: Int, character: Int) async -> Location? {
        guard let uri = fileURI else { return nil }
        return await lspService.requestDefinition(uri: uri, line: line, character: character)
    }
}

// MARK: - Diagnostics Manager

/// LSP 诊断管理器
/// 使用 LanguageServerProtocol 的 Diagnostic 类型
@MainActor
final class LumiDiagnosticsManager: ObservableObject {
    
    private let lspService = LumiLSPService.shared
    
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
final class LumiCompletionProvider: ObservableObject {
    
    private let lspService = LumiLSPService.shared
    
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
    
    @StateObject private var diagnosticsManager = LumiDiagnosticsManager()
    
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
