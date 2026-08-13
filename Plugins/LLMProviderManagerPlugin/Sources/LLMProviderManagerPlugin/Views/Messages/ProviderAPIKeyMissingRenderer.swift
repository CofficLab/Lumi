import KernelLumi
import SwiftUI

private let providerAPIKeyRendererOrder = 350

enum ProviderAPIKeyMissingRenderer {
    static func item(kernel: KernelLumi) -> LumiMessageRendererItem {
        LumiMessageRendererItem(
            id: LumiLLMProviderAPIKeyMessage.renderKind,
            order: providerAPIKeyRendererOrder,
            canRender: { message in
                LumiLLMProviderAPIKeyMessage.isMissingAPIKeyMessage(message)
            },
            render: { message, _ in
                ProviderAPIKeyMissingView(
                    message: message,
                    provider: provider(for: message, kernel: kernel)
                )
            }
        )
    }

    @MainActor
    private static func provider(for message: LumiChatMessage, kernel: KernelLumi) -> (any LumiLLMProvider)? {
        guard let providerID = message.providerID else { return nil }
        return kernel.llmProvider?.llmProvider(id: providerID)
    }
}
