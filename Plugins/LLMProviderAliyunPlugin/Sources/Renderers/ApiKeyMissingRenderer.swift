import LumiCoreKit

enum ApiKeyMissingRenderer {
    static let item = LumiMessageRendererItem(
        id: "aliyun-api-key-missing",
        order: AliyunPlugin.info.order + 200,
        canRender: { message in
            AliyunRenderKind.matchesApiKeyMissing(message)
        },
        render: { message, showRawMessage in
            ApiKeyMissingView(message: message, showRawMessage: showRawMessage)
        }
    )
}
