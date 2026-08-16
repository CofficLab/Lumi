import KernelCore
import LumiUI
import ProviderChatSection
import ProviderConversationInput
import ProviderMessageSender
import SwiftUI

@MainActor
public final class ConversationInputPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.conversation-input"
    public let order = 83
    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self) else { return }
        let input = kernel.resolveProvider((any ConversationInputProviding).self)
        let sender = kernel.resolveProvider((any MessageSendingProviding).self)
        chat.addItems([ChatSectionItem(
            id: id,
            order: 900,
            placement: .bottomFixed,
            showsTrailingDivider: false
        ) {
            ConversationInputView(input: input, sender: sender)
        }])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ChatSectionProviding).self)?.removeItem(id: id)
    }
}

@MainActor
private struct ConversationInputView: View {
    let input: (any ConversationInputProviding)?
    let sender: (any MessageSendingProviding)?
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            AppDivider()
            HStack(alignment: .bottom, spacing: 8) {
                TextField("输入消息，按 Return 发送…", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .padding(8)
                    .foregroundStyle(.primary)
                    .onAppear { draft = input?.text ?? "" }
                Button {
                    let value = draft
                    draft = ""
                    input?.text = ""
                    Task { try? await sender?.sendMessage(value, conversationID: nil) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .background(Color.clear)
        .appSurface(style: .toolbar, cornerRadius: 0)
        .onChange(of: draft) { _, value in input?.text = value }
    }
}
