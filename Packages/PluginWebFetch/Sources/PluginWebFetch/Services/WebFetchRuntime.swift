import KernelCore
import ProviderNetwork

/// WebFetch 插件的运行时持有（KernelCore 体系）。
///
/// 由旧版 `kernel.network` 依赖迁移而来：主插件在 `onBoot` 解析内核的
/// `NetworkProviding` 并注入 fetcher，工具在 `execute` 时读取。
@MainActor
public enum WebFetchRuntime {
    public private(set) static var fetcher: (any WebFetchFetching)?

    public static func configure(kernel: KernelCoreContainer) {
        if let network = kernel.resolveProvider((any NetworkProviding).self) {
            fetcher = KernelWebFetchFetcher(network: network)
        }
    }

    public static func reset() {
        fetcher = nil
    }
}
