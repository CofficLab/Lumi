import LumiKernel
import LumiKernel

private let rendererOrder = 305

enum ApiKeyMissingRenderer {
    static let item = LumiMessageRendererItem(
        id: "aliyun-api-key-missing",
        order: rendererOrder,
        canRender: { message in
            AliyunRenderKind.matchesApiKeyMissing(message)
        },
        render: { message, showRawMessage in
            ApiKeyMissingView(message: message, showRawMessage: showRawMessage)
        }
    )
}
