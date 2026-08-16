import Foundation

// MARK: - Plugin Registry and Lifecycle

extension KernelCoreContainer {
    /// 仅注册插件实例，不执行生命周期。一般宿主应使用 `start(plugins:)`。
    public func registerPlugin(_ plugin: any SuperPlugin) throws {
        guard plugins[plugin.id] == nil else {
            throw KernelCoreError.pluginAlreadyRegistered(id: plugin.id)
        }
        plugins[plugin.id] = plugin
        objectWillChange.send()
    }

    /// 原子启动一批插件。
    ///
    /// 启动前校验重复 id、缺失依赖和依赖环；随后按依赖及 `order` 稳定执行
    /// 全部 Boot，再执行全部 Ready。失败时逆序 Shutdown，并撤销本批插件注册
    /// 的 Provider，避免留下半启动内核。
    public func start(plugins incomingPlugins: [any SuperPlugin]) throws {
        guard lifecycleState == .stopped || lifecycleState == .running else {
            throw KernelCoreError.invalidLifecycleOperation(
                operation: "start plugins",
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
                // 即使 onBoot 中途失败，也必须给插件一次 Shutdown 清理机会。
                bootedIDs.append(plugin.id)
                activePluginID = plugin.id
                try plugin.onBoot(kernel: self)
                activePluginID = nil
                pluginStartOrder.append(plugin.id)
            }

            for plugin in sorted {
                activePluginID = plugin.id
                try plugin.onReady(kernel: self)
                activePluginID = nil
            }
            setLifecycleState(.running)
        } catch {
            activePluginID = nil
            rollbackStartup(bootedIDs: bootedIDs, attemptedIDs: sorted.map(\.id))
            setLifecycleState(previousState == .running ? .running : .failed)
            throw error
        }
    }

    /// 逆启动顺序停止全部插件。某个 Shutdown 失败不会阻断其他插件清理，
    /// 清理完成后抛出遇到的第一个错误。
    public func stop() throws {
        guard lifecycleState == .running || lifecycleState == .failed else {
            if lifecycleState == .stopped { return }
            throw KernelCoreError.invalidLifecycleOperation(operation: "stop", state: lifecycleState)
        }

        setLifecycleState(.stopping)
        var firstError: Error?
        for id in pluginStartOrder.reversed() {
            guard let plugin = plugins[id] else { continue }
            activePluginID = id
            do {
                try plugin.onShutdown(kernel: self)
            } catch {
                if firstError == nil { firstError = error }
            }
            activePluginID = nil
            removeProviders(ownedByPlugin: id)
            plugins.removeValue(forKey: id)
        }
        pluginStartOrder.removeAll()
        activePluginID = nil
        setLifecycleState(.stopped)
        objectWillChange.send()

        if let firstError { throw firstError }
    }

    /// 卸载单个插件。仍被其他插件依赖时拒绝卸载。
    public func unloadPlugin(id: String) throws {
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
        try plugin.onShutdown(kernel: self)
        removeProviders(ownedByPlugin: id)
        plugins.removeValue(forKey: id)
        pluginStartOrder.removeAll { $0 == id }
        objectWillChange.send()
    }

    public func resolvePlugin(id: String) -> (any SuperPlugin)? { plugins[id] }

    public func isPluginRegistered(id: String) -> Bool { plugins[id] != nil }

    public var registeredPluginCount: Int { plugins.count }

    /// 按实际启动顺序返回，保证诊断输出确定性。
    public var allPlugins: [any SuperPlugin] {
        pluginStartOrder.compactMap { plugins[$0] }
            + plugins.values.filter { !pluginStartOrder.contains($0.id) }.sorted { $0.id < $1.id }
    }

    /// 低层注册表操作，不执行 Shutdown。运行中的插件优先使用 `unloadPlugin`。
    public func unregisterPlugin(id: String) {
        plugins.removeValue(forKey: id)
        pluginStartOrder.removeAll { $0 == id }
        removeProviders(ownedByPlugin: id)
        objectWillChange.send()
    }

    private func sortedForStartup(_ incoming: [any SuperPlugin]) throws -> [any SuperPlugin] {
        var byID: [String: any SuperPlugin] = [:]
        var originalIndex: [String: Int] = [:]
        for (index, plugin) in incoming.enumerated() {
            guard plugins[plugin.id] == nil, byID[plugin.id] == nil else {
                throw KernelCoreError.pluginAlreadyRegistered(id: plugin.id)
            }
            byID[plugin.id] = plugin
            originalIndex[plugin.id] = index
        }

        for plugin in incoming {
            for dependency in plugin.dependencies where plugins[dependency] == nil && byID[dependency] == nil {
                throw KernelCoreError.pluginDependencyMissing(
                    pluginID: plugin.id,
                    dependencyID: dependency
                )
            }
        }

        var remaining = Set(byID.keys)
        var resolved = Set(plugins.keys)
        var result: [any SuperPlugin] = []

        while !remaining.isEmpty {
            let ready = remaining.compactMap { byID[$0] }.filter { plugin in
                plugin.dependencies.allSatisfy { resolved.contains($0) }
            }.sorted { lhs, rhs in
                if lhs.order != rhs.order { return lhs.order < rhs.order }
                return originalIndex[lhs.id, default: 0] < originalIndex[rhs.id, default: 0]
            }

            guard !ready.isEmpty else {
                throw KernelCoreError.pluginDependencyCycle(ids: remaining.sorted())
            }
            for plugin in ready {
                remaining.remove(plugin.id)
                resolved.insert(plugin.id)
                result.append(plugin)
            }
        }
        return result
    }

    private func rollbackStartup(bootedIDs: [String], attemptedIDs: [String]) {
        for id in bootedIDs.reversed() {
            guard let plugin = plugins[id] else { continue }
            activePluginID = id
            try? plugin.onShutdown(kernel: self)
            activePluginID = nil
        }
        for id in attemptedIDs {
            removeProviders(ownedByPlugin: id)
            plugins.removeValue(forKey: id)
            pluginStartOrder.removeAll { $0 == id }
        }
        objectWillChange.send()
    }

    private func removeProviders(ownedByPlugin id: String) {
        let keys = providerOwners.compactMap { key, owner in owner == id ? key : nil }
        for key in keys {
            providers.removeValue(forKey: key)
            providerSubscriptions.removeValue(forKey: key)
            providerOwners.removeValue(forKey: key)
        }
    }
}
