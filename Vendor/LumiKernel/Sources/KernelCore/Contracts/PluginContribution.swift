import Foundation

/// 一项由插件写入共享 Host/Provider 的贡献。
///
/// Token 的撤回操作是幂等的。Kernel 会在插件禁用、卸载、启动回滚或停止时
/// 自动调用，插件不再需要依赖一长串手工 `removeXxx` 才能保证没有残留。
@MainActor
public final class PluginContributionToken {
    public let id: UUID
    public let ownerPluginID: String
    private var cleanup: (() -> Void)?

    init(
        id: UUID = UUID(),
        ownerPluginID: String,
        cleanup: @escaping () -> Void
    ) {
        self.id = id
        self.ownerPluginID = ownerPluginID
        self.cleanup = cleanup
    }

    public var isActive: Bool { cleanup != nil }

    public func cancel() {
        guard let cleanup else { return }
        self.cleanup = nil
        cleanup()
    }
}

/// 将一个插件的多项共享贡献作为一个事务提交。
///
/// 事务在 `commit` 前释放或显式 rollback 时会逆序撤回已经执行的外部写入；
/// commit 后由 Kernel 接管这些 cleanup 的生命周期。
@MainActor
public final class PluginContributionTransaction {
    private var cleanups: [() -> Void] = []
    private var isFinished = false

    public init() {}

    public func addCleanup(_ cleanup: @escaping () -> Void) {
        guard !isFinished else { return }
        cleanups.append(cleanup)
    }

    @discardableResult
    public func commit(
        to kernel: KernelCoreContainer,
        ownerPluginID: String? = nil
    ) throws -> [PluginContributionToken] {
        guard !isFinished else { return [] }
        let pending = cleanups
        cleanups.removeAll()
        isFinished = true
        return try pending.map {
            try kernel.trackContribution(ownerPluginID: ownerPluginID, cleanup: $0)
        }
    }

    public func rollback() {
        guard !isFinished else { return }
        isFinished = true
        let pending = cleanups
        cleanups.removeAll()
        for cleanup in pending.reversed() {
            cleanup()
        }
    }

    deinit {
        MainActor.assumeIsolated {
            rollback()
        }
    }
}
