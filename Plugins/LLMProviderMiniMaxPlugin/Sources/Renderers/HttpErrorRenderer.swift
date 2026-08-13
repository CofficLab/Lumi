import KernelLumi
import KernelLumi

enum HttpErrorRenderer {
    private static let pluginOrder = 104 // MiniMaxPlugin.order

    static let item = LumiMessageRendererItem(
        id: "minimax-http-error",
        order: pluginOrder + 200,
        canRender: { message in
            MiniMaxRenderKind.matchesOtherHttpError(message)
        },
        render: { message, _ in
            let statusCode = MiniMaxRenderKind.httpStatusCode(from: message.renderKind)
            HttpErrorView(message: message, statusCode: statusCode)
        }
    )
}