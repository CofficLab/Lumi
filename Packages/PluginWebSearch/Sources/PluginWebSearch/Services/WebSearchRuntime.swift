import KernelCore
import ProviderNetwork

/// WebSearch 插件的运行时持有（KernelCore 体系）。
///
/// 由旧版 `kernel.network` 依赖迁移而来：主插件在 `onBoot` 解析内核的
/// `NetworkProviding` 并注入，工具在 `execute` 时读取，不再依赖 `KernelLumi`。
@MainActor
public enum WebSearchRuntime {
    public private(set) static var network: (any NetworkProviding)?

    public static func configure(kernel: KernelCoreContainer) {
        network = kernel.resolveProvider((any NetworkProviding).self)
    }

    public static func reset() {
        network = nil
    }
}
