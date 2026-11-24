import KitLLM

@MainActor
final class GLMMLXProvider: MLXProviderBase {
    init() {
        super.init(providerID: "mlx-glm", displayName: "GLM")
    }
}