import LumiCoreKit

enum HttpErrorRenderer {
    static let item = LumiMessageRendererItem(
        id: "aliyun-http-error",
        order: info.order + 200,
        canRender: { message in
            AliyunRenderKind.matchesOtherHttpError(message)
        },
        render: { message, showRawMessage in
            let statusCode = AliyunRenderKind.httpStatusCode(from: message.renderKind)
            HttpErrorView(message: message, statusCode: statusCode, showRawMessage: showRawMessage)
        }
    )
}
