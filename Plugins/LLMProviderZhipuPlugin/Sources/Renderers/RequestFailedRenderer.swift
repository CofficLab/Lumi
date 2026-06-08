import LumiCoreKit

enum RequestFailedRenderer {
    static let item = LumiMessageRendererItem(
        id: "zhipu-request-failed",
        order: 210,
        canRender: { message in
            ZhipuRenderKind.matches(renderKind: ZhipuRenderKind.requestFailed, message: message)
        },
        render: { message, showRawMessage in
            HttpErrorView(message: message, statusCode: nil, showRawMessage: showRawMessage)
        }
    )
}
