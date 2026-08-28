import KitLLM

@MainActor
final class DeepSeekMLXProvider: MLXProviderBase {
    init() {
        super.init(providerID: "mlx-deepseek", displayName: "DeepSeek")
    }
}
