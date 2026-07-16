import LumiCoreKit

enum RequestFailedRenderer {
    static let item = LumiMessageRendererItem(
        id: "aliyun-request-failed",
        order: AliyunPlugin.info.order + 200,
        canRender: { message in
            AliyunRenderKind.matches(renderKind: AliyunRenderKind.requestFailed, message: message)
        },
        render: { message, showRawMessage in
            HttpErrorView(message: message, statusCode: nil, showRawMessage: showRawMessage)
        }
    )
}
