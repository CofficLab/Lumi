import LumiCoreKit

enum Http403Renderer {
    static let item = LumiMessageRendererItem(
        id: "zhipu-http-403",
        order: info.order + 200,
        canRender: { message in
            ZhipuRenderKind.matchesHttp(statusCode: 403, message: message)
        },
        render: { message, showRawMessage in
            HttpErrorView(message: message, statusCode: 403, showRawMessage: showRawMessage)
        }
    )
}
