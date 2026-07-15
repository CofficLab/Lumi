import LumiCoreKit

/// 「未配置 API Key」错误渲染器。
enum ApiKeyMissingRenderer {
    static let item = LumiMessageRendererItem(
        id: "xiaomi-api-key-missing",
        order: info.order + 200,
        canRender: { message in
            XiaomiRenderKind.matchesApiKeyMissing(message)
        },
        render: { message, showRawMessage in
            ApiKeyMissingView(message: message, showRawMessage: showRawMessage)
        }
    )
}
