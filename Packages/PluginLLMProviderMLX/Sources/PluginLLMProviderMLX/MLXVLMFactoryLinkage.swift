import Foundation
import MLXVLM

/// 强制链接 `MLXVLM`，使 VLM factory 在运行时可被发现。
///
/// ## 为什么需要它
///
/// `mlx-swift-lm` 通过**运行时动态查找**收集 model factory：
/// ```swift
/// NSClassFromString("MLXVLM.TrampolineModelFactory")
/// ```
///
/// 只在 `Package.swift` 里声明依赖还不够：链接器会把没有任何符号引用的
/// 目标裁掉，`NSClassFromString` 依然返回 `nil`。目录里公开的
/// `Qwen3-VL-*` / `Qwen2-VL-*` 架构只在 VLM 注册表里提供，于是它们在加载
/// 时抛 `ModelFactoryError.unsupportedModelType`——用户明明下载了模型，
/// 却永远进不了生成阶段。
///
/// 这里显式引用 VLM 的 factory 类型，保证该目标被真正链接进二进制。
enum MLXVLMFactoryLinkage {

    /// 引用 VLM 的 model factory，确保 `MLXVLM` 被链接。
    ///
    /// 运行时 `NSClassFromString("MLXVLM.TrampolineModelFactory")` 才能
    /// 找到该类，`ModelFactoryRegistry` 才会把 VLM factory 纳入候选。
    static let modelFactory: MLXVLM.VLMModelFactory.Type = MLXVLM.VLMModelFactory.self
}
