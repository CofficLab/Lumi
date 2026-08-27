import KitLLM

@MainActor
final class GemmaMLXProvider: MLXProviderBase {
    init() {
        super.init(providerID: "mlx-gemma4", displayName: "Gemma")
    }
}
