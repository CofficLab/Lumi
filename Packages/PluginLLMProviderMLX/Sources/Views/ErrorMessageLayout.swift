import KernelLumi
import KernelLumi
import LumiUI
import SwiftUI

/// 错误消息的通用外壳布局：图标 + 标题 + 供应商标签 + 复制按钮 + 自定义内容。
///
/// 历史说明:曾支持"查看原始消息" popover (Binding<Bool> showRawMessage),
/// 该功能已彻底删除;若用户需要查看详细错误,可使用复制按钮整合后的
/// 摘要 + 请求/响应详情内容。
///
/// 与 Zhipu / Xiaomi 插件的 ErrorMessageLayout 等价,保证 MLX 错误消息的视觉一致性。
struct ErrorMessageLayout<Content: View>: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    @ViewBuilder let content: () -> Content

    private var summary: String {
        if !message.content.isEmpty {
            return message.content
        }
        return message.rawErrorDetail ?? ""
    }

    private var requestDetails: String? {
        message.metadata["llm.transport.request"]
    }

    private var responseDetails: String? {
        message.metadata["llm.transport.response"]
    }

    private var copyContent: String {
        var sections: [String] = []
        if !summary.isEmpty {
            sections.append(summary)
        }
        if let requestDetails, !requestDetails.isEmpty {
            sections.append("--- Request ---\n\(requestDetails)")
        }
        if let responseDetails, !responseDetails.isEmpty {
            sections.append("--- Response ---\n\(responseDetails)")
        }
        return sections.joined(separator: "\n\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(theme.error)

                Text(verbatim: LumiPluginLocalization.string("Error", bundle: .module))
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textTertiary)

                ProviderBadge(providerID: message.providerID ?? "")

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(copyContent, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.appMicro)
                }
                .buttonStyle(.plain)
                .foregroundColor(theme.textSecondary)
                .help(LumiPluginLocalization.string("Copy", bundle: .module))
            }

            content()
        }
        .padding(12)
        .frame(maxWidth: 680, alignment: .leading)
        .appSurface(style: .listRow, cornerRadius: 8, borderColor: theme.error.opacity(0.28))
    }
}
