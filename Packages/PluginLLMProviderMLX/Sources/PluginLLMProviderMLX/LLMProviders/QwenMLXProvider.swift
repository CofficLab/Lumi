import KitLLM

@MainActor
final class QwenMLXProvider: MLXProviderBase {
    init() {
        super.init(providerID: "mlx-qwen", displayName: "Qwen")
    }
}
