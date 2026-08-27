import KitLLM

@MainActor
final class CoderMLXProvider: MLXProviderBase {
    init() {
        super.init(providerID: "mlx-coder", displayName: "Coder")
    }
}
