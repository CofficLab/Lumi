import SwiftUI
import CodeEditSourceEditor
import CodeEditTextView
import LanguageServerProtocol

/// Inlay Hint 提供者
/// 在编辑器中显示类型推断、参数名等内联提示
@MainActor
final class InlayHintProvider: ObservableObject {
    
    private let lspService = LSPService.shared
    
    /// 当前可见范围内的 inlay hints
    @Published var hints: [InlayHintItem] = []
    
    /// 检查服务器是否支持 inlay hints
    var isAvailable: Bool {
        // 通过 lspService 的 isAvailable 判断
        lspService.isAvailable
    }
    
    /// 请求可见区域的 inlay hints
    func requestHints(uri: String, startLine: Int, startCharacter: Int, endLine: Int, endCharacter: Int) async {
        let newHints = await lspService.requestInlayHint(
            uri: uri,
            startLine: startLine,
            startCharacter: startCharacter,
            endLine: endLine,
            endCharacter: endCharacter
        ) ?? []
        
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
    
    /// 请求完整文档范围的 hints（当可见区域不可用时）
    func requestFullDocumentHints(uri: String, lineCount: Int) async {
        await requestHints(uri: uri, startLine: 0, startCharacter: 0, endLine: lineCount, endCharacter: 0)
    }
    
    /// 清除所有 hints
    func clear() {
        hints.removeAll()
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
    let id = UUID()
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
            .onTapGesture {
                if let tooltip = hint.tooltip {
                    // TODO: 显示 tooltip
                }
            }
    }
}
