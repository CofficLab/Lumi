import LumiKernel
import LumiUI
import SwiftUI

struct ChatMessageBubble: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    let renderer: LumiMessageRendererItem?
    @Binding var showRawMessage: Bool
    let onUseAsDraft: () -> Void
    let onResend: (() -> Void)?
    let onDelete: () -> Void

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            if !message.content.isEmpty {
                Button {
                    copy(message.content)
                } label: {
                    Label(LumiPluginLocalization.string("Copy", bundle: .module), systemImage: "doc.on.doc")
                }
            }

            if message.role == .user, !message.content.isEmpty {
                Button {
                    onUseAsDraft()
                } label: {
                    Label(LumiPluginLocalization.string("Use as Draft", bundle: .module), systemImage: "arrow.uturn.backward")
                }

                if let onResend {
                    Button(action: onResend) {
                        Label(LumiPluginLocalization.string("Resend", bundle: .module), systemImage: "arrow.clockwise")
                    }
                }
            }

            if message.role != .status {
                Button(role: .destructive, action: onDelete) {
                    Label(LumiPluginLocalization.string("Delete", bundle: .module), systemImage: "trash")
                }
            }

            Button {
                showRawMessage.toggle()
            } label: {
                Label(
                    showRawMessage
                        ? LumiPluginLocalization.string("Hide Raw Message", bundle: .module)
                        : LumiPluginLocalization.string("Show Raw Message", bundle: .module),
                    systemImage: "eye"
                )
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let renderer {
            renderer.render(message, $showRawMessage)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            defaultContent
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var defaultContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(roleTitle(message.role))
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textTertiary)

                if let modelName = message.modelName {
                    Text(modelName)
                        .font(.appMicro)
                        .foregroundColor(theme.textTertiary)
                }

                Spacer()

                Text(message.createdAt, style: .time)
                    .font(.appMicro)
                    .foregroundColor(theme.textTertiary)
            }

            if let reasoning = message.reasoningContent, !reasoning.isEmpty {
                ThinkingBlockView(text: reasoning)
                    .padding(.top, 4)
            }

            if !message.content.isEmpty {
                Text(message.content)
                    .font(.appBody)
                    .foregroundColor(theme.textPrimary)
                    .textSelection(.enabled)
            }

            if showRawMessage {
                Text(rawDescription)
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
        .appSurface(
            style: message.role == .user ? .listRowSelected : .listRow,
            cornerRadius: 8,
            borderColor: message.isError ? theme.error.opacity(0.28) : nil
        )
    }

    private var rawDescription: String {
        [
            "id: \(message.id.uuidString)",
            "role: \(message.role.rawValue)",
            "provider: \(message.providerID ?? "-")",
            "model: \(message.modelName ?? "-")",
            "renderKind: \(message.renderKind ?? "-")",
            "rawError: \(message.rawErrorDetail ?? "-")",
        ].joined(separator: "\n")
    }

    private func roleTitle(_ role: LumiChatMessageRole) -> String {
        switch role {
        case .system:
            LumiPluginLocalization.string("System", bundle: .module)
        case .user:
            LumiPluginLocalization.string("You", bundle: .module)
        case .assistant:
            LumiPluginLocalization.string("Assistant", bundle: .module)
        case .tool:
            LumiPluginLocalization.string("Tool", bundle: .module)
        case .error:
            LumiPluginLocalization.string("Error", bundle: .module)
        case .status:
            LumiPluginLocalization.string("Status", bundle: .module)
        }
    }

    private func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
