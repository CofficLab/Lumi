import Foundation
import os
import ObjectiveC.runtime

/// 编辑器子插件管理器。
/// 负责插件自动发现、注册去重和扩展点注入。
@MainActor
final class EditorPluginManager: ObservableObject {
    struct PluginInfo: Identifiable, Equatable {
        let id: String
        let displayName: String
        let order: Int
        let isConfigurable: Bool
        let isEnabled: Bool
    }

    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "editor.plugin-manager")

    /// 扩展点注册中心（由具体插件写入能力）
    let registry: EditorExtensionRegistry

    /// 已注册的编辑器插件（按 order 排序）
    @Published private(set) var plugins: [any EditorFeaturePlugin] = []
    /// 已发现的编辑器插件元信息（包含已禁用插件）
    @Published private(set) var discoveredPluginInfos: [PluginInfo] = []
    private var discoveredPluginInstances: [any EditorFeaturePlugin] = []

    init(registry: EditorExtensionRegistry = EditorExtensionRegistry()) {
        self.registry = registry
    }

    func register(_ plugin: any EditorFeaturePlugin) {
        if plugins.contains(where: { $0.id == plugin.id }) {
            Self.logger.debug("[EditorPluginManager] 跳过重复插件: \(plugin.id, privacy: .public)")
            return
        }

        plugins.append(plugin)
        plugins.sort { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
        }

        plugin.register(into: registry)
        Self.logger.info("[EditorPluginManager] 注册插件: \(plugin.id, privacy: .public) (\(plugin.displayName, privacy: .public))")
    }

    func isPluginEnabled(_ plugin: any EditorFeaturePlugin) -> Bool {
        if !plugin.isConfigurable { return true }
        return EditorConfigStore.loadEditorPluginEnabled(plugin.id) ?? plugin.isEnabledByDefault
    }

    func setPluginEnabled(_ pluginID: String, enabled: Bool) {
        EditorConfigStore.saveEditorPluginEnabled(pluginID, enabled: enabled)
        applyEnabledPlugins()
    }

    /// 自动发现并注册编辑器内部插件。
    ///
    /// 扫描规则：
    /// 1. 类名位于 `Lumi.` 命名空间
    /// 2. 类名以 `EditorPlugin` 结尾
    /// 3. 能实例化并实现 `EditorFeaturePlugin`
    func autoDiscoverAndRegisterPlugins() {
        var count: UInt32 = 0
        guard let classList = objc_copyClassList(&count) else { return }
        defer { free(UnsafeMutableRawPointer(classList)) }

        let classes = UnsafeBufferPointer(start: classList, count: Int(count))
        var discovered: [any EditorFeaturePlugin] = []

        for cls in classes {
            let className = NSStringFromClass(cls)
            guard className.hasPrefix("Lumi."), className.hasSuffix("EditorPlugin") else { continue }
            guard let object = createInstance(of: cls) else { continue }
            guard let plugin = object as? any EditorFeaturePlugin else { continue }
            discovered.append(plugin)
        }

        discovered.sort { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
        }

        discoveredPluginInstances = discovered
        applyEnabledPlugins()
    }

    private func applyEnabledPlugins() {
        registry.reset()
        plugins.removeAll()

        var infos: [PluginInfo] = []
        for plugin in discoveredPluginInstances {
            let enabled = isPluginEnabled(plugin)
            infos.append(
                PluginInfo(
                    id: plugin.id,
                    displayName: plugin.displayName,
                    order: plugin.order,
                    isConfigurable: plugin.isConfigurable,
                    isEnabled: enabled
                )
            )
            if enabled {
                register(plugin)
            } else {
                Self.logger.info("[EditorPluginManager] 跳过禁用插件: \(plugin.id, privacy: .public)")
            }
        }
        discoveredPluginInfos = infos
    }

    private func createInstance(of cls: AnyClass) -> AnyObject? {
        let allocSelector = NSSelectorFromString("alloc")
        guard let allocMethod = class_getClassMethod(cls, allocSelector) else {
            return nil
        }

        typealias AllocMethod = @convention(c) (AnyClass, Selector) -> AnyObject?
        let allocImpl = unsafeBitCast(method_getImplementation(allocMethod), to: AllocMethod.self)
        guard let instance = allocImpl(cls, allocSelector) else {
            return nil
        }

        let initSelector = NSSelectorFromString("init")
        guard let initMethod = class_getInstanceMethod(cls, initSelector) else {
            return instance
        }

        typealias InitMethod = @convention(c) (AnyObject, Selector) -> AnyObject?
        let initImpl = unsafeBitCast(method_getImplementation(initMethod), to: InitMethod.self)
        return initImpl(instance, initSelector) ?? instance
    }
}
