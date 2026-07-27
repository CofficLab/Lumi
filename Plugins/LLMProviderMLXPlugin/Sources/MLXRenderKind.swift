import LumiKernel
import LumiKernel

/// MLX 供应商错误消息的渲染类型判定。
///
/// 错误消息的 `renderKind` 由 `MLXLumiProvider.errorRenderKind(for:)` 设置，
/// 供 `MLXLumiPlugin.messageRenderers` 选择对应渲染器（如「模型未下载」内联下载界面）。
enum MLXRenderKind {
    /// 模型未下载：渲染成内联下载界面，用户可直接点击下载。
    static let modelNotDownloaded = "mlx-model-not-downloaded"

    /// MLX 相关的 provider id。
    static let providerIDs: Set<String> = ["mlx"]

    /// 是否为 MLX 抛出的错误消息。
    static func isMLXError(_ message: LumiChatMessage) -> Bool {
        guard let providerID = message.providerID else { return false }
        return message.isError && providerIDs.contains(providerID)
    }

    /// `renderKind` 精确匹配。
    static func matches(renderKind expected: String, message: LumiChatMessage) -> Bool {
        isMLXError(message) && message.renderKind == expected
    }

    /// 是否为「模型未下载」错误消息。
    static func matchesModelNotDownloaded(_ message: LumiChatMessage) -> Bool {
        matches(renderKind: modelNotDownloaded, message: message)
    }
}
