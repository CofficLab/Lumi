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
