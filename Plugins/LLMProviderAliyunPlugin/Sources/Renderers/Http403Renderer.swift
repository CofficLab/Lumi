import LumiCoreMessage
import LumiKernel

private let rendererOrder = 305

enum Http403Renderer {
    static let item = LumiMessageRendererItem(
        id: "aliyun-http-403",
        order: rendererOrder,
        canRender: { message in
            AliyunRenderKind.matchesHttp(statusCode: 403, message: message)
        },
        render: { message, showRawMessage in
            HttpErrorView(message: message, statusCode: 403, showRawMessage: showRawMessage)
        }
    )
}
