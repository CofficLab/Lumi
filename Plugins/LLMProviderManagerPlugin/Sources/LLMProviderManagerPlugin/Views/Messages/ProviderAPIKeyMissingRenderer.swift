import LumiKernel
import SwiftUI

private let providerAPIKeyRendererOrder = 350

enum ProviderAPIKeyMissingRenderer {
    static func item(kernel: LumiKernel) -> LumiMessageRendererItem {
        LumiMessageRendererItem(
            id: LumiLLMProviderAPIKeyMessage.renderKind,
            order: providerAPIKeyRendererOrder,
            canRender: { message in
                LumiLLMProviderAPIKeyMessage.isMissingAPIKeyMessage(message)
            },
            render: { message, showRawMessage in
                ProviderAPIKeyMissingView(
                    message: message,
                    provider: provider(for: message, kernel: kernel),
                    showRawMessage: showRawMessage
                )
            }
        )
    }

    @MainActor
    private static func provider(for message: LumiChatMessage, kernel: LumiKernel) -> (any LumiLLMProvider)? {
        guard let providerID = message.providerID else { return nil }
        return kernel.llmProvider?.llmProvider(id: providerID)
    }
}
