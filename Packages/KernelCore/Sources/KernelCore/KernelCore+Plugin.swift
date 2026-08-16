import Foundation

// MARK: - Plugin Registry and Lifecycle

extension KernelCoreContainer {
    /// 仅注册插件实例，不执行生命周期。一般宿主应使用 `start(plugins:)`。
    public func registerPlugin(_ plugin: any SuperPlugin) throws {
        guard plugins[plugin.id] == nil else {
            throw KernelCoreError.pluginAlreadyRegistered(id: plugin.id)
        }
        plugins[plugin.id] = plugin
        pluginEnabledStates[plugin.id] = effectiveEnabledState(for: plugin)
        objectWillChange.send()
    }

    // MARK: - Enable-state persistence

    /// 计算插件的有效启用状态：`required` 策略强制启用；
    /// 否则优先持久化覆盖（先查新 ID，再回退旧 ID 别名），无记录时默认启用。
    func effectiveEnabledState(for plugin: any SuperPlugin) -> Bool {
        if plugin.metadata.policy == .required { return true }
        return storedEnabledState(for: plugin.id) ?? true
    }

    func storedEnabledState(for pluginID: String) -> Bool? {
        guard let store = stateStore else { return nil }
        if let value = store.enabledState(pluginID: pluginID) { return value }
        if let legacyID = legacyPluginIDAliases[pluginID],
           let value = store.enabledState(pluginID: legacyID) {
            return value
        }
        return nil
    }

    /// 持久化插件启用状态：写新 ID，同时同步写旧 ID 别名，
    /// 保证回滚到旧版时状态仍然一致。
    func persistEnabledState(_ enabled: Bool, pluginID: String) {
        guard let store = stateStore else { return }
        store.setEnabled(enabled, pluginID: pluginID)
        if let legacyID = legacyPluginIDAliases[pluginID] {
            store.setEnabled(enabled, pluginID: legacyID)
        }
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

        if let asyncPlugin = incomingPlugins.first(where: { $0 is any AsyncSuperPlugin }) {
            throw KernelCoreError.asyncLifecycleRequired(pluginID: asyncPlugin.id)
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
        if let asyncPlugin = allPlugins.first(where: { $0 is any AsyncSuperPlugin }) {
            throw KernelCoreError.asyncLifecycleRequired(pluginID: asyncPlugin.id)
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
        var shutdownError: Error?
        do {
            try plugin.onShutdown(kernel: self)
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

    public func resolvePlugin(id: String) -> (any SuperPlugin)? { plugins[id] }

    public func isPluginRegistered(id: String) -> Bool { plugins[id] != nil }

    public func isPluginEnabled(id: String) -> Bool {
        pluginEnabledStates[id] == true
    }

    public var registeredPluginCount: Int { plugins.count }

    /// 按实际启动顺序返回，保证诊断输出确定性。
    public var allPlugins: [any SuperPlugin] {
        pluginStartOrder.compactMap { plugins[$0] }
            + plugins.values.filter { !pluginStartOrder.contains($0.id) }.sorted { $0.id < $1.id }
    }

    /// 低层注册表操作，不执行 Shutdown。运行中的插件优先使用 `unloadPlugin`。
    public func unregisterPlugin(id: String) {
        cancelContributions(ownedBy: id)
        plugins.removeValue(forKey: id)
        pluginStartOrder.removeAll { $0 == id }
        pluginEnabledStates.removeValue(forKey: id)
        removeProviders(ownedByPlugin: id)
        objectWillChange.send()
    }

    func sortedForStartup(_ incoming: [any SuperPlugin]) throws -> [any SuperPlugin] {
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
            cancelContributions(ownedBy: id)
            removeProviders(ownedByPlugin: id)
            plugins.removeValue(forKey: id)
            pluginEnabledStates.removeValue(forKey: id)
            pluginStartOrder.removeAll { $0 == id }
        }
        objectWillChange.send()
    }

    func removeProviders(ownedByPlugin id: String) {
        let keys = providerOwners.compactMap { key, owner in owner == id ? key : nil }
        for key in keys {
            providers.removeValue(forKey: key)
            providerSubscriptions.removeValue(forKey: key)
            providerOwners.removeValue(forKey: key)
        }
    }
}
