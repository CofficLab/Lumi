import KernelLumi
import KernelLumi

enum Http403Renderer {
    private static let pluginOrder = 104 // MiniMaxPlugin.order

    static let item = LumiMessageRendererItem(
        id: "minimax-http-403",
        order: pluginOrder + 200,
        canRender: { message in
            MiniMaxRenderKind.matchesHttp(statusCode: 403, message: message)
        },
        render: { message, _ in
            HttpErrorView(message: message, statusCode: 403)
        }
    )
}