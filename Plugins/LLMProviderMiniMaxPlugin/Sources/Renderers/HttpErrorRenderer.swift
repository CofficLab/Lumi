import LumiKernel

enum HttpErrorRenderer {
    static let item = LumiMessageRendererItem(
        id: "minimax-http-error",
        order: MiniMaxPlugin.info.order + 200,
        canRender: { message in
            MiniMaxRenderKind.matchesOtherHttpError(message)
        },
        render: { message, showRawMessage in
            let statusCode = MiniMaxRenderKind.httpStatusCode(from: message.renderKind)
            HttpErrorView(message: message, statusCode: statusCode, showRawMessage: showRawMessage)
        }
    )
}