import LumiCoreMessage
import LumiKernel

enum HttpErrorRenderer {
    static let item = LumiMessageRendererItem(
        id: "zhipu-http-error",
        order: 305,
        canRender: { message in
            ZhipuRenderKind.matchesOtherHttpError(message)
        },
        render: { message, showRawMessage in
            let statusCode = ZhipuRenderKind.httpStatusCode(from: message.renderKind)
            HttpErrorView(message: message, statusCode: statusCode, showRawMessage: showRawMessage)
        }
    )
}
