import LumiKernel
import LumiKernel

enum Http403Renderer {
    static let item = LumiMessageRendererItem(
        id: "zhipu-http-403",
        order: 305,
        canRender: { message in
            ZhipuRenderKind.matchesHttp(statusCode: 403, message: message)
        },
        render: { message, _ in
            HttpErrorView(message: message, statusCode: 403)
        }
    )
}