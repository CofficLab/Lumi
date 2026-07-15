import LumiCoreKit

/// 401 未授权：Key 失效或错误，复用配置界面引导用户重新填写。
enum Http401Renderer {
    static let item = LumiMessageRendererItem(
        id: "xiaomi-http-401",
        order: info.order + 200,
        canRender: { message in
            XiaomiRenderKind.matchesHttp(statusCode: 401, message: message)
        },
        render: { message, showRawMessage in
            ApiKeyMissingView(message: message, showRawMessage: showRawMessage)
        }
    )
}
