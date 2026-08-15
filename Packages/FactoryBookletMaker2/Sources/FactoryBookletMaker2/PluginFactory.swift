import Foundation
import KernelCore

/// 产出各种插件的工厂协议。
///
/// 集中管理插件的构造；`KernelFactory.makeKernel` 通过它产出插件并
/// 用 `kernel.start(plugins:)` 启动。宿主可实现该协议覆盖插件列表。
@MainActor
public protocol PluginFactory {
    /// 产出要启动的全部插件。
    ///
    /// 各插件在 `onBoot` 中解析内核已有 Provider 并注册自己的贡献。
    func makePlugins() -> [any SuperPlugin]
}

/// 默认 `PluginFactory` 实现：产出默认插件。
@MainActor
public struct DefaultPluginFactory: PluginFactory {
    public init() {}

    /// 产出默认插件列表（当前为空，等待逐步填充）。
    public func makePlugins() -> [any SuperPlugin] {
        []
    }
}
