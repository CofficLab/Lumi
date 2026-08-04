import LumiKernel
import LumiUI
import SwiftUI

/// MiniMax 错误消息外壳：与默认错误消息保持一致的 header + 错误正文两段式布局。
struct ErrorMessageLayout<Content: View>: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    @ViewBuilder let content: () -> Content

    private var copyContent: String {
        var sections: [String] = []
        let summary = (message.content.isEmpty ? message.rawErrorDetail ?? "" : message.content)
        if !summary.isEmpty {
            sections.append(summary)
        }
        if let request = message.metadata["llm.transport.request"], !request.isEmpty {
            sections.append("--- Request ---\n\(request)")
        }
        if let response = message.metadata["llm.transport.response"], !response.isEmpty {
            sections.append("--- Response ---\n\(response)")
        }
        return sections.joined(separator: "\n\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                ChatAvatarView(kind: .error)

                AppIdentityRow(
                    title: LumiPluginLocalization.string("Error", bundle: .module),
                    metadata: [
                        message.providerID ?? MiniMaxTokenPlanProvider.info.id,
                        message.modelName ?? "",
                    ]
                )

                Spacer(minLength: 0)

                AppIconButton(systemImage: "doc.on.doc", tint: theme.textSecondary, size: .regular) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(copyContent, forType: .string)
                }
                .help(LumiPluginLocalization.string("Copy", bundle: .module))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .appSurface(
                style: .custom(theme.textSecondary.opacity(0.08)),
                cornerRadius: 10,
                borderColor: theme.divider.opacity(0.65)
            )

            content()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    theme.error.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(theme.error.opacity(0.16), lineWidth: 1)
                )
        }
        // Match normal message flow: fill the available row width instead of
        // creating a centered, narrow error card.
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
