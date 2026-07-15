import LumiCoreKit

enum Http401Renderer {
    static let item = LumiMessageRendererItem(
        id: "aliyun-http-401",
        order: info.order + 200,
        canRender: { message in
            AliyunRenderKind.matchesHttp(statusCode: 401, message: message)
        },
        render: { message, showRawMessage in
            ApiKeyMissingView(message: message, issue: .invalid, showRawMessage: showRawMessage)
        }
    )
}
