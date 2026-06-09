import Foundation
import EditorKernel
import EditorService
import EditorService
import Combine
import CodeEditSourceEditor
import CodeEditTextView
import LanguageServerProtocol

/// Inlay Hint 提供者
/// 在编辑器中显示类型推断、参数名等内联提示
@MainActor
public final class InlayHintProvider: ObservableObject, SuperEditorInlayHintProvider {
    
    private let lspService: LSPService
    private let requestLifecycle = LSPRequestLifecycle()

    public init(lspService: LSPService = .shared) {
        self.lspService = lspService
    }
    
    /// 当前可见范围内的 inlay hints
    @Published public var hints: [InlayHintItem] = []
    
    /// 检查服务器是否支持 inlay hints
    public var isAvailable: Bool {
        lspService.supportsInlayHints
    }
    
    /// 请求可见区域的 inlay hints
    public func requestHints(uri: String, startLine: Int, startCharacter: Int, endLine: Int, endCharacter: Int) async {
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
                    let text = self.formatLabel(hint.label)
                    guard !text.isEmpty else { return nil }
                    return InlayHintItem(
                        line: Int(hint.position.line),
                        character: Int(hint.position.character),
                        text: text,
                        kind: hint.kind,
                        tooltip: self.extractTooltip(from: hint.tooltip),
                        paddingLeft: hint.paddingLeft == true,
                        paddingRight: hint.paddingRight == true
                    )
                }
            }
        )
    }

    /// 重置请求生命周期（切文件或主动清理时）
    public func reset() {
        requestLifecycle.reset()
    }

    /// 清除所有 hints
    public func clear() {
        requestLifecycle.reset()
        hints.removeAll()
    }

    deinit {
        requestLifecycle.reset()
    }

    /// 请求完整文档范围的 hints（当可见区域不可用时）
    public func requestFullDocumentHints(uri: String, lineCount: Int) async {
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
