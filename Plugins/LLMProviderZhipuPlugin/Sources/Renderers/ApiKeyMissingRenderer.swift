import LumiCoreKit

enum ApiKeyMissingRenderer {
    static let item = LumiMessageRendererItem(
        id: "zhipu-api-key-missing",
        order: 210,
        canRender: { message in
            ZhipuRenderKind.matchesApiKeyMissing(message)
        },
        render: { message, showRawMessage in
            ApiKeyMissingView(message: message, showRawMessage: showRawMessage)
        }
    )
}
