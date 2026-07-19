import LumiKernel

enum Http403Renderer {
    static let item = LumiMessageRendererItem(
        id: "minimax-http-403",
        order: MiniMaxPlugin.info.order + 200,
        canRender: { message in
            MiniMaxRenderKind.matchesHttp(statusCode: 403, message: message)
        },
        render: { message, showRawMessage in
            HttpErrorView(message: message, statusCode: 403, showRawMessage: showRawMessage)
        }
    )
}