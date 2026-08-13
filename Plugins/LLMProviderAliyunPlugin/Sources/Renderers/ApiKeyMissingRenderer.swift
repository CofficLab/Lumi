import KernelLumi
import KernelLumi

private let rendererOrder = 305

enum ApiKeyMissingRenderer {
    static let item = LumiMessageRendererItem(
        id: "aliyun-api-key-missing",
        order: rendererOrder,
        canRender: { message in
            AliyunRenderKind.matchesApiKeyMissing(message)
        },
        render: { message, _ in
            ApiKeyMissingView(message: message)
        }
    )
}