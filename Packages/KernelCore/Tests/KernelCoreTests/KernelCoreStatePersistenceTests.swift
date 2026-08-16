import Foundation
import Testing
@testable import KernelCore

@Suite("KernelCore Plugin State Persistence")
@MainActor
struct KernelCoreStatePersistenceTests {
    private final class TestPlugin: SuperPlugin {
        let id: String
        let metadata: PluginMetadata
        init(id: String, policy: PluginEnablePolicy = .enabledByDefault) {
            self.id = id
            self.metadata = PluginMetadata(id: id, policy: policy)
        }
    }

    private func freshStore() -> (UserDefaults, UserDefaultsPluginStateStore) {
        let suite = "KernelCoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (defaults, UserDefaultsPluginStateStore(defaults: defaults, keyPrefix: "test.v1"))
    }

    @Test("disable 持久化后，新内核重新注册时保持禁用")
    func disablePersistsAcrossKernels() async throws {
        let (_, store) = freshStore()
        let kernel = KernelCoreContainer()
        kernel.stateStore = store
        let plugin = TestPlugin(id: "opt-out")

        try await kernel.startAsync(plugins: [plugin])
        #expect(kernel.isPluginEnabled(id: "opt-out"))

        try await kernel.disablePlugin(id: "opt-out")
        #expect(!kernel.isPluginEnabled(id: "opt-out"))
        try await kernel.stopAsync()

        // 模拟重启：新内核 + 同一 store，重新注册同一插件
        let kernel2 = KernelCoreContainer()
        kernel2.stateStore = store
        try await kernel2.startAsync(plugins: [TestPlugin(id: "opt-out")])
        #expect(!kernel2.isPluginEnabled(id: "opt-out"))
        try await kernel2.stopAsync()
    }

    @Test("enable 持久化后，重新注册保持启用")
    func enablePersistsAcrossKernels() async throws {
        let (_, store) = freshStore()
        let kernel = KernelCoreContainer()
        kernel.stateStore = store
        let plugin = TestPlugin(id: "opt-in")
        try kernel.start(plugins: [plugin])
        #expect(kernel.isPluginEnabled(id: "opt-in"))

        try await kernel.disablePlugin(id: "opt-in")
        #expect(!kernel.isPluginEnabled(id: "opt-in"))
        try await kernel.enablePlugin(id: "opt-in")
        #expect(kernel.isPluginEnabled(id: "opt-in"))

        let kernel2 = KernelCoreContainer()
        kernel2.stateStore = store
        try kernel2.start(plugins: [TestPlugin(id: "opt-in")])
        #expect(kernel2.isPluginEnabled(id: "opt-in"))
    }

    @Test("required 策略插件忽略持久化禁用")
    func requiredPolicyIgnoresDisabledState() async throws {
        let (_, store) = freshStore()
        let kernel = KernelCoreContainer()
        kernel.stateStore = store
        let plugin = TestPlugin(id: "must-run", policy: .required)

        try await kernel.startAsync(plugins: [plugin])
        // required 插件不可被 disablePlugin 禁用
        await #expect(throws: KernelCoreError.self) {
            try await kernel.disablePlugin(id: "must-run")
        }
        #expect(kernel.isPluginEnabled(id: "must-run"))
        try await kernel.stopAsync()

        // 即使存储被手动写入 false，required 插件仍强制启用
        store.setEnabled(false, pluginID: "must-run")
        let kernel2 = KernelCoreContainer()
        kernel2.stateStore = store
        try await kernel2.startAsync(plugins: [TestPlugin(id: "must-run", policy: .required)])
        #expect(kernel2.isPluginEnabled(id: "must-run"))
        try await kernel2.stopAsync()
    }

    @Test("alwaysOn 策略插件默认启用且不可禁用（对齐旧版 alwaysOn）")
    func alwaysOnPolicyIsEnabledAndNotDisableable() async throws {
        let (_, store) = freshStore()
        let kernel = KernelCoreContainer()
        kernel.stateStore = store
        // 显式 alwaysOn 策略（协议默认值由 SuperPluginTests 单独断言）
        let plugin = TestPlugin(id: "always-on", policy: .alwaysOn)

        try await kernel.startAsync(plugins: [plugin])
        #expect(plugin.metadata.policy == .alwaysOn)
        #expect(!plugin.metadata.policy.isConfigurable)
        #expect(kernel.isPluginEnabled(id: "always-on"))

        // alwaysOn 插件不可被 disablePlugin 禁用
        await #expect(throws: KernelCoreError.self) {
            try await kernel.disablePlugin(id: "always-on")
        }
        #expect(kernel.isPluginEnabled(id: "always-on"))
        try await kernel.stopAsync()

        // 即使存储被手动写入 false，alwaysOn 插件仍强制启用
        store.setEnabled(false, pluginID: "always-on")
        let kernel2 = KernelCoreContainer()
        kernel2.stateStore = store
        try await kernel2.startAsync(plugins: [TestPlugin(id: "always-on", policy: .alwaysOn)])
        #expect(kernel2.isPluginEnabled(id: "always-on"))
        try await kernel2.stopAsync()
    }

    @Test("旧插件 ID 别名回退查询启用状态")
    func legacyIDAliasFallback() async throws {
        let (_, store) = freshStore()
        // 旧版只写旧 ID 的状态
        store.setEnabled(false, pluginID: "com.legacy.plugin.opt-out")

        let kernel = KernelCoreContainer()
        kernel.stateStore = store
        kernel.legacyPluginIDAliases = ["com.new.plugin.opt-out": "com.legacy.plugin.opt-out"]

        try await kernel.startAsync(plugins: [TestPlugin(id: "com.new.plugin.opt-out")])
        // 新 ID 无记录 → 回退旧 ID → false
        #expect(!kernel.isPluginEnabled(id: "com.new.plugin.opt-out"))
        try await kernel.stopAsync()

        // 新 ID 有记录时优先新 ID
        let (_, store2) = freshStore()
        store2.setEnabled(false, pluginID: "com.legacy.plugin.opt-out")
        store2.setEnabled(true, pluginID: "com.new.plugin.opt-out")
        let kernel2 = KernelCoreContainer()
        kernel2.stateStore = store2
        kernel2.legacyPluginIDAliases = ["com.new.plugin.opt-out": "com.legacy.plugin.opt-out"]
        try await kernel2.startAsync(plugins: [TestPlugin(id: "com.new.plugin.opt-out")])
        #expect(kernel2.isPluginEnabled(id: "com.new.plugin.opt-out"))
        try await kernel2.stopAsync()
    }

    @Test("持久化同时写新 ID 与旧 ID 别名，回滚兼容")
    func persistWritesBothIDs() async throws {
        let (defaults, store) = freshStore()
        let kernel = KernelCoreContainer()
        kernel.stateStore = store
        kernel.legacyPluginIDAliases = ["com.new.plugin.x": "com.legacy.plugin.x"]

        try await kernel.startAsync(plugins: [TestPlugin(id: "com.new.plugin.x")])
        try await kernel.disablePlugin(id: "com.new.plugin.x")
        try await kernel.stopAsync()

        #expect(store.enabledState(pluginID: "com.new.plugin.x") == false)
        #expect(store.enabledState(pluginID: "com.legacy.plugin.x") == false)
        // 真实 UserDefaults 中同样可读
        #expect(defaults.object(forKey: "test.v1.com.new.plugin.x") as? Bool == false)
        #expect(defaults.object(forKey: "test.v1.com.legacy.plugin.x") as? Bool == false)
    }
}
