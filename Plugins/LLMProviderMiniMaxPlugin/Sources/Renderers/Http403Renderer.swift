import LumiCoreKit

enum Http403Renderer {
    static let item = LumiMessageRendererItem(
        id: "minimax-http-403",
        order: 210,
        canRender: { message in
            MiniMaxRenderKind.matchesHttp(statusCode: 403, message: message)
        },
        render: { message, showRawMessage in
            HttpErrorView(message: message, statusCode: 403, showRawMessage: showRawMessage)
        }
    )
}