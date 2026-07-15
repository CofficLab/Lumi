import LumiCoreKit

enum HttpErrorRenderer {
    static let item = LumiMessageRendererItem(
        id: "zhipu-http-error",
        order: info.order + 200,
        canRender: { message in
            ZhipuRenderKind.matchesOtherHttpError(message)
        },
        render: { message, showRawMessage in
            let statusCode = ZhipuRenderKind.httpStatusCode(from: message.renderKind)
            HttpErrorView(message: message, statusCode: statusCode, showRawMessage: showRawMessage)
        }
    )
}
