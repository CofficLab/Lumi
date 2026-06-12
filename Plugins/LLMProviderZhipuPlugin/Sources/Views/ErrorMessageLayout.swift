import LumiCoreKit
import LumiUI
import SwiftUI

struct ErrorMessageLayout<Content: View>: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    @Binding var showRawMessage: Bool
    @ViewBuilder let content: () -> Content

    private var copyContent: String {
        if !message.content.isEmpty {
            return message.content
        }
        return message.rawErrorDetail ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(theme.error)

                Text(verbatim: LumiPluginLocalization.string("Error", bundle: .module))
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textTertiary)

                ProviderBadge()

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

                Button {
                    showRawMessage.toggle()
                } label: {
                    Image(systemName: showRawMessage ? "eye.slash" : "eye")
                        .font(.appMicro)
                }
                .buttonStyle(.plain)
                .foregroundColor(theme.textSecondary)
                .help(LumiPluginLocalization.string("Toggle raw message", bundle: .module))
            }

            content()

            if showRawMessage {
                Text(copyContent.isEmpty ? message.renderKind ?? "" : copyContent)
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appSurface(style: .panel, cornerRadius: 6)
            }
        }
        .padding(12)
        .frame(maxWidth: 680, alignment: .leading)
        .appSurface(style: .listRow, cornerRadius: 8, borderColor: theme.error.opacity(0.28))
    }
}
