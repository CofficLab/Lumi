import LumiKernel
import LumiKernel

enum RequestFailedRenderer {
    static let item = LumiMessageRendererItem(
        id: "zhipu-request-failed",
        order: 305,
        canRender: { message in
            ZhipuRenderKind.matches(renderKind: ZhipuRenderKind.requestFailed, message: message)
        },
        render: { message, showRawMessage in
            HttpErrorView(message: message, statusCode: nil, showRawMessage: showRawMessage)
        }
    )
}
