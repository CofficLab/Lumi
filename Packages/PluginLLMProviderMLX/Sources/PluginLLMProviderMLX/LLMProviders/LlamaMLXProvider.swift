import KitLLM

@MainActor
final class LlamaMLXProvider: MLXProviderBase {
    init() {
        super.init(providerID: "mlx-llama", displayName: "Llama")
    }
}
