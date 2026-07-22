import LumiKernel
import LumiKernel

enum Http401Renderer {
    static let item = LumiMessageRendererItem(
        id: "zhipu-http-401",
        order: 305,
        canRender: { message in
            ZhipuRenderKind.matchesHttp(statusCode: 401, message: message)
        },
        render: { message, showRawMessage in
            ApiKeyMissingView(message: message, showRawMessage: showRawMessage)
        }
    )
}
