import LumiKernel

/// 请求失败（网络错误等，无 HTTP 状态码）。
enum RequestFailedRenderer {
    static let item = LumiMessageRendererItem(
        id: "xiaomi-request-failed",
        order: XiaomiPlugin.info.order + 200,
        canRender: { message in
            XiaomiRenderKind.matches(renderKind: XiaomiRenderKind.requestFailed, message: message)
        },
        render: { message, showRawMessage in
            HttpErrorView(message: message, statusCode: nil, showRawMessage: showRawMessage)
        }
    )
}
