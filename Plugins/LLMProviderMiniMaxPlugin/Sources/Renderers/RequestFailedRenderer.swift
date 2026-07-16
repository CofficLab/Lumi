import LumiCoreKit

enum RequestFailedRenderer {
    static let item = LumiMessageRendererItem(
        id: "minimax-request-failed",
        order: MiniMaxPlugin.info.order + 200,
        canRender: { message in
            MiniMaxRenderKind.matches(renderKind: MiniMaxRenderKind.requestFailed, message: message)
        },
        render: { message, showRawMessage in
            HttpErrorView(message: message, statusCode: nil, showRawMessage: showRawMessage)
        }
    )
}