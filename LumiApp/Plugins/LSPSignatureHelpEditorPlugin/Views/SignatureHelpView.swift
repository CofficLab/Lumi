import SwiftUI
import LumiUI

/// 签名帮助浮层视图。
///
/// 用于展示 LSP `textDocument/signatureHelp` 返回的当前函数/方法签名、参数列表，
/// 并突出当前正在输入的参数。该视图只负责渲染 `SignatureHelpItem`，
/// 请求和状态维护由 `SignatureHelpProvider` 负责，显示时机和位置由编辑器 Overlay 决定。
struct SignatureHelpView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    
    let item: SignatureHelpItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 函数签名
            Text(item.label)
                .font(.appMonoCaption)
                .foregroundColor(theme.textPrimary)
                .lineLimit(2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .appSurface(style: .subtle, cornerRadius: 6)
            
            // 参数列表
            if !item.parameters.isEmpty {
                Divider().opacity(0.3)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(item.parameters.enumerated()), id: \.element.id) { index, param in
                            HStack(alignment: .top, spacing: 6) {
                                Text("\(index)")
                                    .font(.appMicroEmphasized)
                                    .foregroundColor(theme.textSecondary)
                                    .frame(width: 20, alignment: .trailing)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(param.label)
                                        .font(.appMonoMicro)
                                        .fontWeight(index == item.activeParameterIndex ? .bold : .regular)
                                        .foregroundColor(
                                            index == item.activeParameterIndex
                                                ? theme.primary
                                                : theme.textPrimary
                                        )
                                    
                                    if let doc = param.documentation, !doc.isEmpty {
                                        Text(doc)
                                            .font(.appMicro)
                                            .foregroundColor(theme.textSecondary)
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
        .appSurface(
            style: .popover,
            cornerRadius: 8,
            borderColor: theme.divider
        )
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
        .frame(maxWidth: 450)
    }
}
