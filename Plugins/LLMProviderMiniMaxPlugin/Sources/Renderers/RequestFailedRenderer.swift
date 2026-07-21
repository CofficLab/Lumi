import LumiKernel
import LumiCoreMessage

enum RequestFailedRenderer {
    private static let pluginOrder = 104 // MiniMaxPlugin.order

    static let item = LumiMessageRendererItem(
        id: "minimax-request-failed",
        order: pluginOrder + 200,
        canRender: { message in
            MiniMaxRenderKind.matches(renderKind: MiniMaxRenderKind.requestFailed, message: message)
        },
        render: { message, showRawMessage in
            HttpErrorView(message: message, statusCode: nil, showRawMessage: showRawMessage)
        }
    )
}
