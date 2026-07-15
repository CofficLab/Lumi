import LumiCoreKit

/// 其它 HTTP 错误（非 401/403，如 429 限流、500 服务器错误等）。
enum HttpErrorRenderer {
    static let item = LumiMessageRendererItem(
        id: "xiaomi-http-error",
        order: XiaomiPlugin.info.order + 200,
        canRender: { message in
            XiaomiRenderKind.matchesOtherHttpError(message)
        },
        render: { message, showRawMessage in
            let statusCode = XiaomiRenderKind.httpStatusCode(from: message.renderKind)
            HttpErrorView(message: message, statusCode: statusCode, showRawMessage: showRawMessage)
        }
    )
}
