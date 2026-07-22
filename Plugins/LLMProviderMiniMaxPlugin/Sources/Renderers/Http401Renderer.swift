import LumiKernel
import LumiKernel

enum Http401Renderer {
    private static let pluginOrder = 104 // MiniMaxPlugin.order

    static let item = LumiMessageRendererItem(
        id: "minimax-http-401",
        order: pluginOrder + 200,
        canRender: { message in
            MiniMaxRenderKind.matchesHttp(statusCode: 401, message: message)
        },
        render: { message, showRawMessage in
            ApiKeyMissingView(message: message, issue: .invalid, showRawMessage: showRawMessage)
        }
    )
}
