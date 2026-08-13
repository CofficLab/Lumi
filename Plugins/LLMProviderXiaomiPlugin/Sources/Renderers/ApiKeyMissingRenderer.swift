import KernelLumi
import KernelLumi

/// 「未配置 API Key」错误渲染器。
enum ApiKeyMissingRenderer {
    private static let pluginOrder = 102 // XiaomiPlugin.order

    static let item = LumiMessageRendererItem(
        id: "xiaomi-api-key-missing",
        order: pluginOrder + 200,
        canRender: { message in
            XiaomiRenderKind.matchesApiKeyMissing(message)
        },
        render: { message, _ in
            ApiKeyMissingView(message: message)
        }
    )
}