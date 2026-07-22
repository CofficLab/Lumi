import LumiKernel
import LumiKernel

/// 「模型未下载」错误渲染器：在内联消息气泡上直接提供下载入口。
///
/// 当 `MLXLumiProvider` 因所选模型未下载而失败时，错误消息的 `renderKind` 会被
/// 设为 `MLXRenderKind.modelNotDownloaded`，本渲染器据此渲染内联下载界面，
/// 用户可直接在消息上点击下载，下载完成后一键重发。
enum ModelNotDownloadedRenderer {
    private static let pluginOrder = 95 // MLXLumiPlugin.order

    static let item = LumiMessageRendererItem(
        id: "mlx-model-not-downloaded",
        // 高于核心错误渲染器（order 300），确保优先匹配。
        order: pluginOrder + 215,
        canRender: { message in
            MLXRenderKind.matchesModelNotDownloaded(message)
        },
        render: { message, showRawMessage in
            ModelNotDownloadedView(message: message, showRawMessage: showRawMessage)
        }
    )
}
