import LumiKernel
import LumiCoreMessage

enum ApiKeyMissingRenderer {
    private static let pluginOrder = 104 // MiniMaxPlugin.order

    static let item = LumiMessageRendererItem(
        id: "minimax-api-key-missing",
        order: pluginOrder + 200,
        canRender: { message in
            MiniMaxRenderKind.matchesApiKeyMissing(message)
        },
        render: { message, showRawMessage in
            ApiKeyMissingView(message: message, showRawMessage: showRawMessage)
        }
    )
}
