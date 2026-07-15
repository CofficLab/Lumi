import LumiCoreKit

/// 403 禁止访问：权限不足或 Key 无权访问该模型。
enum Http403Renderer {
    static let item = LumiMessageRendererItem(
        id: "xiaomi-http-403",
        order: XiaomiPlugin.info.order + 200,
        canRender: { message in
            XiaomiRenderKind.matchesHttp(statusCode: 403, message: message)
        },
        render: { message, showRawMessage in
            HttpErrorView(message: message, statusCode: 403, showRawMessage: showRawMessage)
        }
    )
}
