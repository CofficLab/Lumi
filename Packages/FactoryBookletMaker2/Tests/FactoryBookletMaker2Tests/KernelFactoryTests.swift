import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderNetwork
import ProviderPluginManaging
import ProviderProject
import ProviderRailView
import ProviderRootView
import ProviderSettingView
import ProviderStorage
import ProviderToast
import ProviderToolbar
import Testing
@testable import FactoryBookletMaker2

/// KernelFactory 装配逻辑的测试：makeKernel 注册全部默认 Provider，
/// 主视图与设置视图组装不崩溃。
@Suite("KernelFactory")
@MainActor
struct KernelFactoryTests {

    // MARK: - makeKernel

    @Test("makeKernel 注册全部默认 Provider")
    func makeKernelRegistersAllProviders() throws {
        let kernel = try KernelFactory.makeKernel()

        #expect(kernel.registeredProviderCount == 11)
        #expect(kernel.resolveProvider((any StorageProviding).self) != nil)
        #expect(kernel.resolveProvider((any ContentViewProviding).self) != nil)
        #expect(kernel.resolveProvider((any DocsViewProviding).self) != nil)
        #expect(kernel.resolveProvider((any ProjectProviding).self) != nil)
        #expect(kernel.resolveProvider((any ToastProviding).self) != nil)
        #expect(kernel.resolveProvider((any NetworkProviding).self) != nil)
        #expect(kernel.resolveProvider((any ToolbarProviding).self) != nil)
        #expect(kernel.resolveProvider((any RootViewProviding).self) != nil)
        #expect(kernel.resolveProvider((any ActivityBarProviding).self) != nil)
        #expect(kernel.resolveProvider((any RailViewProviding).self) != nil)
        #expect(kernel.resolveProvider((any SettingViewProviding).self) != nil)
    }

    @Test("makeKernel 每次产出全新容器，互不共享 Provider")
    func makeKernelReturnsFreshContainers() throws {
        let a = try KernelFactory.makeKernel()
        let b = try KernelFactory.makeKernel()

        #expect(a !== b)
        #expect(
            a.resolveProvider((any StorageProviding).self) !== nil
                && b.resolveProvider((any StorageProviding).self) !== nil
        )
    }

    // MARK: - View Assembly

    @Test("makeMainView 返回非空根视图")
    func makeMainViewReturnsView() throws {
        let view = try KernelFactory.makeMainView()
        _ = view // AnyView 装配成功即视为通过（不崩溃、不返回占位 Text）
    }

    @Test("makeSettingsView 返回非空设置视图")
    func makeSettingsViewReturnsView() throws {
        let view = try KernelFactory.makeSettingsView()
        _ = view
    }
}

/// 工厂默认实现的测试：DefaultPluginFactory 产出空插件列表。
@Suite("Default Factories")
@MainActor
struct DefaultFactoryTests {

    @Test("DefaultPluginFactory 产出空插件列表")
    func defaultPluginsEmpty() {
        #expect(DefaultPluginFactory().makePlugins().isEmpty)
    }
}

// MARK: - PluginManaging Filtering Tests

/// 用于测试的 mock PluginManaging：可指定哪些插件 ID 应当被过滤掉。
@MainActor
private final class MockPluginManaging: PluginManaging {
    var disabledIDs: Set<String>

    init(disabledIDs: Set<String> = []) {
        self.disabledIDs = disabledIDs
    }

    // MARK: - PluginControlling

    var lastErrorDescription: String?

    func enablePlugin(id: String) async -> Bool {
        disabledIDs.remove(id)
        return true
    }

    func disablePlugin(id: String) async -> Bool {
        disabledIDs.insert(id)
        return true
    }

    func isEnabled(id: String) -> Bool {
        !disabledIDs.contains(id)
    }

    // MARK: - PluginManaging

    var allPlugins: [any SuperPlugin] { [] }
    var configurablePlugins: [any SuperPlugin] { [] }
    var pluginCount: Int { 0 }
    var enabledCount: Int { 0 }

    func plugin(id: String) -> (any SuperPlugin)? { nil }
    func isRegistered(id: String) -> Bool { false }
    func unloadPlugin(id: String) throws {}
    func reloadPlugin(id: String) throws {}

    func enabledPlugins(from candidates: [any SuperPlugin]) -> [any SuperPlugin] {
        candidates.filter { plugin in
            guard plugin.metadata.policy.isConfigurable else { return true }
            return isEnabled(id: plugin.id)
        }
    }

    @discardableResult
    func addPluginObserver(_ callback: @escaping (PluginManagingEvent) -> Void) -> any PluginManagingObserverHandle {
        MockObserverHandle()
    }
}

@MainActor
private final class MockObserverHandle: PluginManagingObserverHandle {
    func cancel() {}
}

/// 用于测试的 mock 插件。
@MainActor
private final class MockPlugin: SuperPlugin {
    let id: String
    let metadata: PluginMetadata

    init(id: String, policy: PluginEnablePolicy = .enabledByDefault) {
        self.id = id
        self.metadata = PluginMetadata(id: id, policy: policy)
    }
}

@Suite("PluginManaging Filtering")
@MainActor
struct PluginManagingFilteringTests {

    @Test("enabledPlugins 保留不可配置插件（required）")
    func keepsRequiredPlugins() {
        let manager = MockPluginManaging(disabledIDs: ["required-plugin"])
        let required = MockPlugin(id: "required-plugin", policy: .required)
        let result = manager.enabledPlugins(from: [required])
        #expect(result.count == 1)
        #expect(result.first?.id == "required-plugin")
    }

    @Test("enabledPlugins 保留不可配置插件（alwaysOn）")
    func keepsAlwaysOnPlugins() {
        let manager = MockPluginManaging(disabledIDs: ["always-on-plugin"])
        let alwaysOn = MockPlugin(id: "always-on-plugin", policy: .alwaysOn)
        let result = manager.enabledPlugins(from: [alwaysOn])
        #expect(result.count == 1)
        #expect(result.first?.id == "always-on-plugin")
    }

    @Test("enabledPlugins 过滤掉用户禁用的可配置插件")
    func filtersDisabledConfigurablePlugins() {
        let manager = MockPluginManaging(disabledIDs: ["disabled-plugin"])
        let enabled = MockPlugin(id: "enabled-plugin", policy: .enabledByDefault)
        let disabled = MockPlugin(id: "disabled-plugin", policy: .enabledByDefault)
        let result = manager.enabledPlugins(from: [enabled, disabled])
        #expect(result.count == 1)
        #expect(result.first?.id == "enabled-plugin")
    }

    @Test("enabledPlugins 保持原始顺序")
    func preservesOrder() {
        let manager = MockPluginManaging(disabledIDs: [])
        let a = MockPlugin(id: "a", policy: .enabledByDefault)
        let b = MockPlugin(id: "b", policy: .enabledByDefault)
        let c = MockPlugin(id: "c", policy: .enabledByDefault)
        let result = manager.enabledPlugins(from: [a, b, c])
        #expect(result.map(\.id) == ["a", "b", "c"])
    }

    @Test("enabledPlugins 空列表返回空")
    func emptyCandidatesReturnsEmpty() {
        let manager = MockPluginManaging()
        let result = manager.enabledPlugins(from: [])
        #expect(result.isEmpty)
    }
}
