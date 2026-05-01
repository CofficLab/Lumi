import SwiftUI
import CodeEditSourceEditor
import CodeEditTextView
import LanguageServerProtocol

/// Inlay Hint 提供者
/// 在编辑器中显示类型推断、参数名等内联提示
@MainActor
final class InlayHintProvider: ObservableObject, SuperEditorInlayHintProvider {
    
    private let lspService: LSPService
    private let requestLifecycle = LSPRequestLifecycle()

    init(lspService: LSPService = .shared) {
        self.lspService = lspService
    }
    
    /// 当前可见范围内的 inlay hints
    @Published var hints: [InlayHintItem] = []
    
    /// 检查服务器是否支持 inlay hints
    var isAvailable: Bool {
        lspService.supportsInlayHints
    }
    
    /// 请求可见区域的 inlay hints
    func requestHints(uri: String, startLine: Int, startCharacter: Int, endLine: Int, endCharacter: Int) async {
        requestLifecycle.run(
            operation: { [lspService] in
                await lspService.requestInlayHint(
                    uri: uri,
                    startLine: startLine,
                    startCharacter: startCharacter,
                    endLine: endLine,
                    endCharacter: endCharacter
                ) ?? []
            },
            apply: { [weak self] newHints in
                guard let self else { return }
                hints = newHints.compactMap { hint in
                    let text = formatLabel(hint.label)
                    guard !text.isEmpty else { return nil }
                    return InlayHintItem(
                        line: Int(hint.position.line),
                        character: Int(hint.position.character),
                        text: text,
                        kind: hint.kind,
                        tooltip: extractTooltip(from: hint.tooltip),
                        paddingLeft: hint.paddingLeft == true,
                        paddingRight: hint.paddingRight == true
                    )
                }
            }
        )
    }

    /// 重置请求生命周期（切文件或主动清理时）
    func reset() {
        requestLifecycle.reset()
    }

    /// 清除所有 hints
    func clear() {
        requestLifecycle.reset()
        hints.removeAll()
    }

    deinit {
        requestLifecycle.reset()
    }

    /// 请求完整文档范围的 hints（当可见区域不可用时）
    func requestFullDocumentHints(uri: String, lineCount: Int) async {
        await requestHints(uri: uri, startLine: 0, startCharacter: 0, endLine: lineCount, endCharacter: 0)
    }
    
    // MARK: - Helpers
    
    private func formatLabel(_ label: TwoTypeOption<String, [InlayHintLabelPart]>) -> String {
        switch label {
        case .optionA(let str):
            return str
        case .optionB(let parts):
            return parts.map { $0.value }.joined(separator: "")
        }
    }
    
    private func extractTooltip(from tooltip: TwoTypeOption<String, MarkupContent>?) -> String? {
        guard let tooltip else { return nil }
        switch tooltip {
        case .optionA(let str): return str
        case .optionB(let markup): return markup.value
        }
    }
}

/// Inlay Hint 数据模型
struct InlayHintItem: Identifiable {
    var id: String { "\(line):\(character):\(text)" }
    let line: Int
    let character: Int
    let text: String
    let kind: InlayHintKind?
    let tooltip: String?
    let paddingLeft: Bool
    let paddingRight: Bool
    
    /// 是否为类型提示
    var isTypeHint: Bool {
        kind == .type
    }
    
    /// 是否为参数名提示
    var isParameterHint: Bool {
        kind == .parameter
    }
}

// MARK: - UI View

/// 内联提示标签视图（用于叠加在编辑器文本上）
struct InlayHintLabel: View {
    
    let hint: InlayHintItem
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Text(hint.text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(
                hint.isTypeHint
                    ? Color(nsColor: .secondaryLabelColor)
                    : Color(nsColor: .tertiaryLabelColor)
            )
            .padding(.horizontal, hint.paddingLeft ? 6 : 0)
            .padding(.horizontal, hint.paddingRight ? 6 : 0)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            )
            .help(hint.tooltip ?? "")
    }
}

// MARK: - Visible range for LSP `textDocument/inlayHint`

enum EditorInlayHintLayout {
    /// 将可见区域映射为 LSP 行范围（0-based），供 `textDocument/inlayHint` 使用
    static func visibleDocumentLSPRange(in textView: TextView) -> LSPRange? {
        let str = textView.string
        guard !str.isEmpty, let lm = textView.layoutManager else { return nil }

        let vis = textView.visibleRect
        let hInset = textView.edgeInsets + textView.textInsets
        let top = CGPoint(x: vis.minX + hInset.left + 4, y: vis.minY + 4)
        let bottom = CGPoint(x: vis.midX, y: max(vis.minY + 4, vis.maxY - 4))

        guard let startOffset = lm.textOffsetAtPoint(top),
              let endOffset = lm.textOffsetAtPoint(bottom) else { return nil }

        let pad = 400
        let len = str.utf16.count
        let lo = max(0, min(startOffset, endOffset) - pad)
        let hi = min(len, max(startOffset, endOffset) + pad)

        let startPos = lspPosition(utf16Offset: lo, in: str)
        let endPos = lspPosition(utf16Offset: hi, in: str)
        return LSPRange(
            start: Position(line: startPos.line, character: startPos.character),
            end: Position(line: endPos.line, character: endPos.character)
        )
    }

    private static func lspPosition(utf16Offset: Int, in content: String) -> (line: Int, character: Int) {
        var line = 0
        var column = 0
        var offset = 0
        for scalar in content.unicodeScalars {
            let len = scalar.utf16.count
            if offset + len > utf16Offset {
                return (line, column)
            }
            if scalar == "\n" {
                line += 1
                column = 0
            } else {
                column += len
            }
            offset += len
        }
        return (line, column)
    }
}
