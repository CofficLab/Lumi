import KitLLM

@MainActor
final class GPTOSSMLXProvider: MLXProviderBase {
    init() {
        super.init(providerID: "mlx-gptoss", displayName: "GPT-OSS")
    }
}