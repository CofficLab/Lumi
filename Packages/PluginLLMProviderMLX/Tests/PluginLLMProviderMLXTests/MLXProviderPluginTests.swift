import Testing
import KernelCore
import KitLLM
import ProviderLLMManager
@testable import PluginLLMProviderMLX

@Suite("PluginLLMProviderMLX")
struct MLXProviderPluginTests {
    @Test("注册 5.16.0 的七个本地 MLX 供应商")
    @MainActor
    func registersAllLocalProviders() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        try MLXProviderPlugin().onBoot(kernel: kernel)

        #expect(manager.providerCount == 7)
        #expect(manager.allProviders().allSatisfy { $0.providerInfo.isLocal })
        #expect(manager.allProviders().allSatisfy { $0 is any LLMModelDownloadProviding })
        #expect(MLXProviderCatalog.registrations.count == 32)
        #expect(manager.allProviders().map { $0.providerInfo.id } == [
            "mlx-qwen", "mlx-llama", "mlx-mistral", "mlx-gemma4",
            "mlx-deepseek", "mlx-coder", "mlx-microsoft",
        ])
    }

}
