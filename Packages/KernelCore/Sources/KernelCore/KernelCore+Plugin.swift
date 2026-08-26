import Foundation

// MARK: - Plugin Registry and Lifecycle

extension KernelCoreContainer {
    /// 仅注册插件实例，不执行生命周期。一般宿主应使用 `start(plugins:)`。
    public func registerPlugin(_ plugin: any SuperPlugin) throws {
        guard plugins[plugin.id] == nil else {
            throw KernelCoreError.pluginAlreadyRegistered(id: plugin.id)
        }
        plugins[plugin.id] = plugin
        pluginEnabledStates[plugin.id] = plugin.metadata.policy.enabledByDefault
        activePluginID = plugin.id
        do {
            try plugin.onRegister(kernel: self)
            activePluginID = nil
            objectWillChange.send()
        } catch {
            activePluginID = nil
            cancelContributions(ownedBy: plugin.id)
            plugins.removeValue(forKey: plugin.id)
            pluginEnabledStates.removeValue(forKey: plugin.id)
            throw error
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

        // 彻底排除策略为 .disabled 的插件：不注册、不启动、不展示。
        let activePlugins = incomingPlugins.filter { $0.metadata.policy != .disabled }

        let previousState = lifecycleState
        let sorted = try sortedForStartup(activePlugins)
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

                // 用户已禁用的插件仅注册、不 Boot：跳过 onBoot/onReady，
                // 等待运行时 enablePlugin 时再恢复。
                guard isPluginEnabled(id: plugin.id) else { continue }

                activePluginID = plugin.id
                try plugin.onBoot(kernel: self)
                activePluginID = nil
                pluginStartOrder.append(plugin.id)
            }

            for plugin in sorted {
                guard isPluginEnabled(id: plugin.id) else { continue }
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
        }
        let registeredPlugins = allPlugins
        for plugin in registeredPlugins.reversed() {
            activePluginID = plugin.id
            do {
                try plugin.onUnregister(kernel: self)
            } catch {
                if firstError == nil { firstError = error }
            }
            activePluginID = nil
            cancelContributions(ownedBy: plugin.id)
            removeProviders(ownedByPlugin: plugin.id)
            plugins.removeValue(forKey: plugin.id)
            pluginEnabledStates.removeValue(forKey: plugin.id)
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
        if pluginStartOrder.contains(id) {
            do {
                try plugin.onShutdown(kernel: self)
            } catch {
                shutdownError = error
            }
        }
        do {
            try plugin.onUnregister(kernel: self)
        } catch {
            if shutdownError == nil { shutdownError = error }
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
        if let plugin = plugins[id] {
            activePluginID = id
            try? plugin.onUnregister(kernel: self)
            activePluginID = nil
        }
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
            if let plugin = plugins[id] {
                activePluginID = id
                try? plugin.onUnregister(kernel: self)
                activePluginID = nil
            }
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
