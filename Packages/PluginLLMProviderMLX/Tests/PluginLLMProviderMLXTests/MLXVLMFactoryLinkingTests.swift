import Foundation
import Testing
import MLXLMCommon
@testable import PluginLLMProviderMLX

/// MLX 的 VL 模型必须有对应的 VLM factory。
///
/// ## 为什么要有这条测试
///
/// MLX 目录公开了 `Qwen3-VL-2B-Instruct-4bit`、`Qwen3-VL-4B-Instruct-4bit`
/// 与 `Qwen2-VL-7B-Instruct-4bit` 三个视觉模型，用户可以下载它们。
///
/// 但 `mlx-swift-lm` 是**运行时动态发现** factory 的：它用
/// `NSClassFromString("MLXVLM.TrampolineModelFactory")` 找 VLM factory。
/// 目标没有链接 `MLXVLM` 时，这个类根本不在二进制里，只有 LLM factory
/// 可用——而 `qwen2_vl` / `qwen3_vl` 只在 VLM 注册表里提供。
///
/// 结果是：目录公开并可下载的模型，在加载时抛
/// `ModelFactoryError.unsupportedModelType`，永远进不了生成阶段。
@Suite("MLX VLM factory 的链接")
struct MLXVLMFactoryLinkingTests {

    @Test("MLXVLM 的 trampoline factory 在运行时可被发现")
    func vlmTrampolineFactoryIsDiscoverable() {
        let factoryClass = NSClassFromString("MLXVLM.TrampolineModelFactory")

        #expect(
            factoryClass != nil,
            "MLXVLM 未被链接：找不到 TrampolineModelFactory，VL 模型加载会抛 unsupportedModelType"
        )
    }

    @Test("factory 注册表非空（LLM factory 至少可用）")
    func factoryRegistryIsNotEmpty() {
        let factories = ModelFactoryRegistry.shared.modelFactories()

        #expect(
            !factories.isEmpty,
            "factory 注册表为空，没有任何模型能被加载"
        )
    }
}
