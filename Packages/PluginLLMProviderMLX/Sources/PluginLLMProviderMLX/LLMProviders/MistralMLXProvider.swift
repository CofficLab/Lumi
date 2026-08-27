import KitLLM

@MainActor
final class MistralMLXProvider: MLXProviderBase {
    init() {
        super.init(providerID: "mlx-mistral", displayName: "Mistral")
    }
}
