import Foundation
import Testing
import KernelCore
import KitLLM
import KitTestIsolation
import ProviderLLMManager
import ProviderStorage
@testable import PluginLLMProviderMLX

@Suite("PluginLLMProviderMLX")
struct MLXProviderPluginTests {
    @Test("注册 5.16.0 的七个本地 MLX 供应商")
    @MainActor
    func registersAllLocalProviders() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)
        // 存储 Provider 决定模型根目录与运行时目录。测试进程里守卫拒绝回退到
        // 本机真实目录，因此 boot 必须能拿到真实（临时目录）Provider 才能继续。
        try kernel.registerProvider(
            (any StorageProviding).self,
            MLXProviderTestDoubles.StubStorageProvider(
                root: MLXProviderTestDoubles.makeTemporaryDirectory("boot")
            )
        )

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

    @Test("启动时把存储目录注入模型根目录与运行时目录")
    @MainActor
    func bootInjectsStorageDirectory() throws {
        let root = MLXProviderTestDoubles.makeTemporaryDirectory("runtime-boot")
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any LLMManaging).self, DefaultLLMManager())
        try kernel.registerProvider(
            (any StorageProviding).self,
            MLXProviderTestDoubles.StubStorageProvider(root: root)
        )

        try MLXProviderPlugin().onBoot(kernel: kernel)

        let expected = root.appendingPathComponent(
            "com.coffic.lumi.plugin.llm-provider.mlx",
            isDirectory: true
        )
        #expect(MLXModelPaths.rootDirectory == expected)
        #expect(MLXProviderRuntime.settingsDirectory() == expected)
    }
}

/// 运行时目录守卫的测试。
///
/// `MLXModelPaths.rootDirectory` 与 `MLXProviderRuntime.settingsDirectory()` 在测试
/// 进程里未注入即拒绝（`fatalError`，直接终止整个测试进程），因此这里既不能依赖
/// 生产回退目录，也不能让注入状态在用例之间互相污染。
///
/// 所有涉及注入状态的用例都标注 `@MainActor` 且不同步挂起：MainActor 是串行
/// 执行器，这些用例因此不会并发读写同一份进程级注入状态。
@Suite("MLX 运行时目录", .serialized)
@MainActor
struct MLXRuntimeIsolationTests {

    @Test("注入目录后 rootDirectory 返回该目录")
    func modelPathsUseInjectedDirectory() {
        let directory = MLXProviderTestDoubles.makeTemporaryDirectory("model-paths")
        MLXModelPaths.configure(rootDirectory: directory)

        #expect(MLXModelPaths.rootDirectory == directory)
        #expect(MLXModelPaths.modelsDirectory == directory.appendingPathComponent("models", isDirectory: true))
        #expect(
            MLXModelPaths.modelDirectory(for: "mlx-community/Qwen3-0.6B-4bit")
                == directory
                    .appendingPathComponent("models", isDirectory: true)
                    .appendingPathComponent("mlx-community", isDirectory: true)
                    .appendingPathComponent("Qwen3-0.6B-4bit", isDirectory: true)
        )
    }

    @Test("未注入目录时守卫拒绝回退到真实数据目录")
    func modelPathsRefuseWithoutInjectedDirectory() {
        switch IsolatedDirectoryGuard.resolve(
            injected: nil,
            owner: "MLXModelPaths",
            accessor: "rootDirectory",
            fallback: { URL(fileURLWithPath: "/tmp/mlx-model-paths-fallback", isDirectory: true) }
        ) {
        case .resolved:
            Issue.record("测试进程下未注入目录时不应回退到真实数据目录")
        case let .refused(reason):
            #expect(reason.contains("MLXModelPaths"))
            #expect(reason.contains("rootDirectory"))
        }
    }

    @Test("注入目录后 settingsDirectory 返回该目录")
    func providerRuntimeUseInjectedDirectory() {
        let directory = MLXProviderTestDoubles.makeTemporaryDirectory("provider-runtime")
        MLXProviderRuntime.configure(settingsDirectory: directory)
        defer { MLXProviderRuntime.reset() }

        #expect(MLXProviderRuntime.settingsDirectory() == directory)
    }

    @Test("重置后清空注入目录，不再回退到真实数据目录")
    func providerRuntimeResetClearsInjectedDirectory() {
        let directory = MLXProviderTestDoubles.makeTemporaryDirectory("provider-runtime-reset")
        MLXProviderRuntime.configure(settingsDirectory: directory)
        MLXProviderRuntime.reset()

        #expect(MLXProviderRuntime.injectedSettingsDirectory == nil)

        // 重置之后不得再回退到本机真实数据目录：测试进程里这条路径必须被拒绝。
        switch IsolatedDirectoryGuard.resolve(
            injected: MLXProviderRuntime.injectedSettingsDirectory,
            owner: "MLXProviderRuntime",
            accessor: "settingsDirectory()",
            fallback: { URL(fileURLWithPath: "/tmp/mlx-provider-fallback", isDirectory: true) }
        ) {
        case .resolved:
            Issue.record("测试进程下未注入目录时不应回退到真实数据目录")
        case let .refused(reason):
            #expect(reason.contains("MLXProviderRuntime"))
            #expect(reason.contains("settingsDirectory()"))
        }
    }
}
