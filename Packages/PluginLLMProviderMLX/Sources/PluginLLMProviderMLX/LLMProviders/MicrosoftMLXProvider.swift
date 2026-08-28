import KitLLM

@MainActor
final class MicrosoftMLXProvider: MLXProviderBase {
    init() {
        super.init(providerID: "mlx-microsoft", displayName: "Microsoft")
    }
}
