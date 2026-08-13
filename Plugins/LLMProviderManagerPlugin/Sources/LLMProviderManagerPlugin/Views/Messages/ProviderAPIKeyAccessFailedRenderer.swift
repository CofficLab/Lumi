import KernelLumi

private let providerAPIKeyAccessFailedRendererOrder = 351

enum ProviderAPIKeyAccessFailedRenderer {
    static func item(kernel: KernelLumi) -> LumiMessageRendererItem {
        LumiMessageRendererItem(
            id: LumiLLMProviderAPIKeyMessage.accessFailedRenderKind,
            order: providerAPIKeyAccessFailedRendererOrder,
            canRender: { message in
                LumiLLMProviderAPIKeyMessage.isAPIKeyAccessFailedMessage(message)
            },
            render: { message, _ in
                ProviderAPIKeyAccessFailedView(
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
