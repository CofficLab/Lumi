import SwiftUI
import CodeEditSourceEditor
import CodeEditTextView
import LanguageServerProtocol

/// 签名帮助提供者
/// 监听输入触发字符，在光标位置显示函数签名信息
@MainActor
final class SignatureHelpProvider: ObservableObject {
    
    private let lspService = LSPService.shared
    
    /// 当前签名帮助信息
    @Published var currentHelp: SignatureHelpItem?
    /// 是否正在加载
    @Published var isLoading: Bool = false
    
    /// 签名触发字符
    var triggerCharacters: Set<String> {
        // SourceKit-LSP and most servers use "(", ",", "<"
        return ["(", ",", "<"]
    }
    
    /// 检查服务器是否支持签名帮助
    var isAvailable: Bool {
        lspService.isAvailable
    }
    
    /// 请求签名帮助
    func requestSignatureHelp(uri: String, line: Int, character: Int) async {
        isLoading = true
        let help = await lspService.requestSignatureHelp(uri: uri, line: line, character: character)
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
            documentation: extractDocumentation(from: activeSignature.documentation),
            parameters: activeSignature.parameters?.compactMap { param -> SignatureParam? in
                guard let label = extractParamLabel(from: param.label) else { return nil }
                return SignatureParam(
                    label: label,
                    documentation: extractParamDocumentation(from: param.documentation)
                )
            } ?? [],
            activeParameterIndex: activeParamIndex
        )
    }
    
    /// 当签名面板消失时调用
    func clear() {
        currentHelp = nil
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

/// 签名帮助数据模型
struct SignatureHelpItem: Identifiable {
    let id = UUID()
    let label: String
    let documentation: String?
    let parameters: [SignatureParam]
    let activeParameterIndex: Int
}

struct SignatureParam: Identifiable {
    let id = UUID()
    let label: String
    let documentation: String?
}

// MARK: - UI Views

/// 签名帮助视图
struct SignatureHelpView: View {
    
    let item: SignatureHelpItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 函数签名
            Text(item.label)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.95))
            
            // 参数列表
            if !item.parameters.isEmpty {
                Divider().opacity(0.3)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(item.parameters.enumerated()), id: \.element.id) { index, param in
                            HStack(alignment: .top, spacing: 6) {
                                Text("\(index)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, alignment: .trailing)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(param.label)
                                        .font(.system(size: 11, design: .monospaced))
                                        .fontWeight(index == item.activeParameterIndex ? .bold : .regular)
                                        .foregroundColor(
                                            index == item.activeParameterIndex
                                                ? .accentColor
                                                : .primary
                                        )
                                    
                                    if let doc = param.documentation, !doc.isEmpty {
                                        Text(doc)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(4)
                }
                .frame(maxHeight: 150)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
        )
        .frame(maxWidth: 450)
    }
}
