import Foundation
import EditorKernel
import EditorService
import Combine
import CodeEditSourceEditor
import EditorCodeEditTextView
import LanguageServerProtocol
import LSPServiceEditorPlugin

/// 签名帮助提供者
/// 监听输入触发字符，在光标位置显示函数签名信息
@MainActor
public final class SignatureHelpProvider: ObservableObject, SuperEditorSignatureHelpProvider {
    
    private let lspService: LSPService
    private let requestLifecycle = LSPRequestLifecycle()

    public init(lspService: LSPService = .shared) {
        self.lspService = lspService
    }
    
    /// 当前签名帮助信息
    @Published public var currentHelp: SignatureHelpItem?
    /// 是否正在加载
    @Published public var isLoading: Bool = false
    
    /// 签名触发字符
    public var triggerCharacters: Set<String> {
        // SourceKit-LSP and most servers use "(", ",", "<"
        return ["(", ",", "<"]
    }
    
    /// 检查服务器是否支持签名帮助
    public var isAvailable: Bool {
        lspService.isAvailable
    }
    
    /// 请求签名帮助
    public func requestSignatureHelp(
        uri: String,
        line: Int,
        character: Int,
        preflight: (() -> Bool)? = nil
    ) async {
        if preflight?() == false {
            clear()
            return
        }
        isLoading = true
        requestLifecycle.run(
            operation: { [lspService] in
                await lspService.requestSignatureHelp(uri: uri, line: line, character: character)
            },
            apply: { [weak self] help in
                guard let self else { return }
                isLoading = false

                guard let help, !help.signatures.isEmpty else {
                    currentHelp = nil
                    return
                }

                let activeIndex = help.activeSignature ?? 0
                guard activeIndex < help.signatures.count else {
                    currentHelp = nil
                    return
                }

                let activeSignature = help.signatures[activeIndex]
                let activeParamIndex = help.activeParameter ?? 0

                currentHelp = SignatureHelpItem(
                    label: activeSignature.label,
                    documentation: self.extractDocumentation(from: activeSignature.documentation),
                    parameters: activeSignature.parameters?.compactMap { param -> SignatureParam? in
                        guard let label = self.extractParamLabel(from: param.label) else { return nil }
                        return SignatureParam(
                            label: label,
                            documentation: self.extractParamDocumentation(from: param.documentation)
                        )
                    } ?? [],
                    activeParameterIndex: activeParamIndex
                )
            }
        )
    }
    
    /// 当签名面板消失时调用
    public func clear() {
        requestLifecycle.reset()
        currentHelp = nil
        isLoading = false
    }

    public func reset() {
        requestLifecycle.reset()
    }
    
    // MARK: - Helpers
    
    private func extractDocumentation(from doc: TwoTypeOption<String, MarkupContent>?) -> String? {
        guard let doc else { return nil }
        switch doc {
        case .optionA(let str): return str
        case .optionB(let markup): return markup.value
        }
    }
    
    private func extractParamDocumentation(from doc: TwoTypeOption<String, MarkupContent>?) -> String? {
        guard let doc else { return nil }
        switch doc {
        case .optionA(let str): return str
        case .optionB(let markup): return markup.value
        }
    }
    
    private func extractParamLabel(from label: TwoTypeOption<String, [UInt]>) -> String? {
        switch label {
        case .optionA(let str): return str
        case .optionB: return nil
        }
    }
}
