import Foundation

// MARK: - Asynchronous plugin lifecycle and runtime activation

/// 生命周期各阶段的可配置超时。
///
/// 超时后该插件的回调任务会被取消（Swift Task 取消传播），内核进入失败回滚；
/// 插件实现应响应 `Task.isCancelled` 及时退出，避免超时后仍在后台执行。
public struct KernelLifecycleTimeout: Sendable {
    public var boot: Duration
    public var ready: Duration
    public var shutdown: Duration

    public init(
        boot: Duration = .seconds(30),
        ready: Duration = .seconds(30),
        shutdown: Duration = .seconds(15)
    ) {
        self.boot = boot
        self.ready = ready
        self.shutdown = shutdown
    }

    public static let `default` = KernelLifecycleTimeout()
}

private actor LifecycleTimeoutState {
    private(set) var didTimeout = false

    func markTimedOut() {
        didTimeout = true
    }
}

/// 超时后取消生命周期任务，并把迟到结果统一映射成 lifecycleTimeout。
/// 插件仍必须响应 Swift Task cancellation；无法取消的外部同步调用不会被强杀，
/// 但其结果不会被当作生命周期成功。
@MainActor
private func withLifecycleTimeout<T: Sendable>(
    _ timeout: Duration?,
    phase: String,
    pluginID: String,
    operation: @MainActor @Sendable @escaping () async throws -> T
) async throws -> T {
    guard let timeout else { return try await operation() }
    let state = LifecycleTimeoutState()
    let operationTask = Task { @MainActor in
        try await operation()
    }
    let timeoutTask = Task {
        do {
            try await Task.sleep(for: timeout)
            await state.markTimedOut()
            operationTask.cancel()
        } catch is CancellationError {
            // 正常完成或外部取消会终止计时任务。
        }
    }

    return try await withTaskCancellationHandler {
        defer { timeoutTask.cancel() }
        do {
            let result = try await operationTask.value
            if await state.didTimeout {
                throw KernelCoreError.lifecycleTimeout(pluginID: pluginID, phase: phase)
            }
            return result
        } catch {
            if await state.didTimeout {
                throw KernelCoreError.lifecycleTimeout(pluginID: pluginID, phase: phase)
            }
            throw error
        }
    } onCancel: {
        operationTask.cancel()
        timeoutTask.cancel()
    }
}

public extension KernelCoreContainer {
    /// 支持异步插件的原子启动入口。同步插件也可以通过本方法启动。
    ///
    /// - Parameter timeout: 每阶段（boot/ready）的超时配置；传 `nil` 表示单阶段不设限。
    func startAsync(
        plugins incomingPlugins: [any SuperPlugin],
        timeout: KernelLifecycleTimeout? = .default
    ) async throws {
        guard lifecycleState == .stopped || lifecycleState == .running else {
            throw KernelCoreError.invalidLifecycleOperation(
                operation: "start plugins asynchronously",
                state: lifecycleState
            )
        }

        let previousState = lifecycleState
        let sorted = try sortedForStartup(incomingPlugins)
        guard !sorted.isEmpty else {
            if lifecycleState == .stopped { setLifecycleState(.running) }
            return
        }

        setLifecycleState(.starting)
        var bootedIDs: [String] = []

        do {
            for plugin in sorted {
                try registerPlugin(plugin)
                bootedIDs.append(plugin.id)
                activePluginID = plugin.id
                if let plugin = plugin as? any AsyncSuperPlugin {
                    try await withLifecycleTimeout(timeout?.boot, phase: "boot", pluginID: plugin.id) {
                        try await plugin.onBootAsync(kernel: self)
                    }
                } else {
                    try await withLifecycleTimeout(timeout?.boot, phase: "boot", pluginID: plugin.id) {
                        try plugin.onBoot(kernel: self)
                    }
                }
                activePluginID = nil
                pluginStartOrder.append(plugin.id)
            }

            for plugin in sorted {
                activePluginID = plugin.id
                if let plugin = plugin as? any AsyncSuperPlugin {
                    try await withLifecycleTimeout(timeout?.ready, phase: "ready", pluginID: plugin.id) {
                        try await plugin.onReadyAsync(kernel: self)
                    }
                } else {
                    try await withLifecycleTimeout(timeout?.ready, phase: "ready", pluginID: plugin.id) {
                        try plugin.onReady(kernel: self)
                    }
                }
                activePluginID = nil
            }
            setLifecycleState(.running)
        } catch {
            activePluginID = nil
            await rollbackAsyncStartup(
                bootedIDs: bootedIDs,
                attemptedIDs: sorted.map(\.id),
                timeout: timeout
            )
            setLifecycleState(previousState == .running ? .running : .failed)
            throw error
        }
    }

    /// 逆启动顺序异步停止所有插件；清理会继续执行并在最后抛出首个错误。
    ///
    /// - Parameter timeout: shutdown 阶段超时；传 `nil` 表示不设限。
    func stopAsync(timeout: KernelLifecycleTimeout? = .default) async throws {
        guard lifecycleState == .running || lifecycleState == .failed else {
            if lifecycleState == .stopped { return }
            throw KernelCoreError.invalidLifecycleOperation(
                operation: "stop plugins asynchronously",
                state: lifecycleState
            )
        }

        setLifecycleState(.stopping)
        var firstError: Error?
        for id in pluginStartOrder.reversed() {
            guard let plugin = plugins[id] else { continue }
            activePluginID = id
            do {
                if let plugin = plugin as? any AsyncSuperPlugin {
                    try await withLifecycleTimeout(timeout?.shutdown, phase: "shutdown", pluginID: id) {
                        try await plugin.onShutdownAsync(kernel: self)
                    }
                } else {
                    try await withLifecycleTimeout(timeout?.shutdown, phase: "shutdown", pluginID: id) {
                        try plugin.onShutdown(kernel: self)
                    }
                }
            } catch {
                if firstError == nil { firstError = error }
            }
            activePluginID = nil
            cancelContributions(ownedBy: id)
            removeProviders(ownedByPlugin: id)
            plugins.removeValue(forKey: id)
            pluginEnabledStates.removeValue(forKey: id)
        }
        pluginStartOrder.removeAll()
        activePluginID = nil
        setLifecycleState(.stopped)
        objectWillChange.send()

        if let firstError { throw firstError }
    }

    /// 运行时禁用插件。Provider 保持注册以兼容旧版 Boot/Enable 分层，插件登记到
    /// Kernel 的共享贡献会被自动撤回；插件应在 `onDisable` 停止其它运行时资源。
    func disablePlugin(id: String) async throws {
        guard lifecycleState == .running else {
            throw KernelCoreError.invalidLifecycleOperation(operation: "disable plugin", state: lifecycleState)
        }
        guard let plugin = plugins[id] else {
            throw KernelCoreError.pluginNotFound(id: id)
        }
        guard isPluginEnabled(id: id) else { return }
        guard plugin.metadata.policy != .required && plugin.metadata.policy != .alwaysOn else {
            throw KernelCoreError.pluginRequired(id: id)
        }
        if let dependent = plugins.values.first(where: {
            isPluginEnabled(id: $0.id) && $0.dependencies.contains(id)
        }) {
            throw KernelCoreError.invalidLifecycleOperation(
                operation: "disable plugin '\(id)' required by '\(dependent.id)'",
                state: lifecycleState
            )
        }

        activePluginID = id
        defer { activePluginID = nil }
        try await plugin.onDisable(kernel: self)
        cancelContributions(ownedBy: id)
        pluginEnabledStates[id] = false
        persistEnabledState(false, pluginID: id)
        objectWillChange.send()
    }

    /// 运行时重新启用已注册插件。插件在 `onEnable` 中恢复动态资源与贡献。
    func enablePlugin(id: String) async throws {
        guard lifecycleState == .running else {
            throw KernelCoreError.invalidLifecycleOperation(operation: "enable plugin", state: lifecycleState)
        }
        guard let plugin = plugins[id] else {
            throw KernelCoreError.pluginNotFound(id: id)
        }
        guard !isPluginEnabled(id: id) else { return }
        for dependencyID in plugin.dependencies where !isPluginEnabled(id: dependencyID) {
            throw KernelCoreError.pluginDependencyDisabled(
                pluginID: id,
                dependencyID: dependencyID
            )
        }

        activePluginID = id
        defer { activePluginID = nil }
        do {
            try await plugin.onEnable(kernel: self)
        } catch {
            // onEnable 可能已经向多个共享 Host 写入部分贡献；启用失败时
            // 必须恢复到禁用前的无贡献状态。
            cancelContributions(ownedBy: id)
            throw error
        }
        pluginEnabledStates[id] = true
        persistEnabledState(true, pluginID: id)
        objectWillChange.send()
    }

    /// 异步卸载一个插件，兼容同步与异步 Shutdown 实现。
    func unloadPluginAsync(id: String) async throws {
        guard lifecycleState == .running else {
            throw KernelCoreError.invalidLifecycleOperation(operation: "unload plugin", state: lifecycleState)
        }
        guard let plugin = plugins[id] else {
            throw KernelCoreError.pluginNotFound(id: id)
        }
        if let dependent = plugins.values.first(where: { $0.dependencies.contains(id) }) {
            throw KernelCoreError.invalidLifecycleOperation(
                operation: "unload plugin '\(id)' required by '\(dependent.id)'",
                state: lifecycleState
            )
        }

        activePluginID = id
        defer { activePluginID = nil }
        var shutdownError: Error?
        do {
            if let plugin = plugin as? any AsyncSuperPlugin {
                try await plugin.onShutdownAsync(kernel: self)
            } else {
                try plugin.onShutdown(kernel: self)
            }
        } catch {
            shutdownError = error
        }
        cancelContributions(ownedBy: id)
        removeProviders(ownedByPlugin: id)
        plugins.removeValue(forKey: id)
        pluginEnabledStates.removeValue(forKey: id)
        pluginStartOrder.removeAll { $0 == id }
        objectWillChange.send()
        if let shutdownError { throw shutdownError }
    }

    private func rollbackAsyncStartup(
        bootedIDs: [String],
        attemptedIDs: [String],
        timeout: KernelLifecycleTimeout? = .default
    ) async {
        for id in bootedIDs.reversed() {
            guard let plugin = plugins[id] else { continue }
            activePluginID = id
            if let plugin = plugin as? any AsyncSuperPlugin {
                try? await withLifecycleTimeout(timeout?.shutdown, phase: "rollback-shutdown", pluginID: id) {
                    try await plugin.onShutdownAsync(kernel: self)
                }
            } else {
                try? plugin.onShutdown(kernel: self)
            }
            activePluginID = nil
        }
        for id in attemptedIDs {
            cancelContributions(ownedBy: id)
            removeProviders(ownedByPlugin: id)
            plugins.removeValue(forKey: id)
            pluginEnabledStates.removeValue(forKey: id)
            pluginStartOrder.removeAll { $0 == id }
        }
        objectWillChange.send()
    }
}
