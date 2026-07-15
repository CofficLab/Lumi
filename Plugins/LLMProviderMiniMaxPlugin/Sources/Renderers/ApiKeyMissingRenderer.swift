import LumiCoreKit

enum ApiKeyMissingRenderer {
    static let item = LumiMessageRendererItem(
        id: "minimax-api-key-missing",
        order: info.order + 200,
        canRender: { message in
            MiniMaxRenderKind.matchesApiKeyMissing(message)
        },
        render: { message, showRawMessage in
            ApiKeyMissingView(message: message, showRawMessage: showRawMessage)
        }
    )
}