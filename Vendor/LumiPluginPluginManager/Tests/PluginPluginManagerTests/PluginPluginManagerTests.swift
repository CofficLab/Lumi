import Foundation
import KernelCore
import ProviderPluginManaging
import ProviderPromptSuggestion
import ProviderSettingView
import Testing

@testable import PluginPluginManager

@MainActor
struct PluginPluginManagerTests {

    @Test("插件列表刷新时包含稍后注册的插件")
    func viewModelRefreshesPluginsRegisteredAfterInitialSnapshot() {
        let firstPlugin = TestPlugin(id: "first", policy: .enabledByDefault)
        let latePlugin = TestPlugin(id: "late", policy: .disabledByDefault)
        let capability = TestPluginManagementCapability(plugins: [firstPlugin])
        let viewModel = PluginManagementViewModel(
            capability: capability,
            docsCapability: PluginManagerDocsCapabilityAdapter(docs: nil)
        )

        viewModel.refresh()
        #expect(viewModel.plugins.map(\.id) == ["first"])

        capability.plugins.append(latePlugin)
        viewModel.refresh()
        #expect(viewModel.plugins.map(\.id) == ["first", "late"])
    }

    /// 启用状态筛选只保留匹配的插件，且与分类 / 关键字筛选叠加。
    @Test("启用状态筛选按启用与否收窄列表")
    func statusFilterNarrowsPlugins() {
        let enabled = TestPlugin(id: "enabled", policy: .enabledByDefault)
        let disabled = TestPlugin(id: "disabled", policy: .disabledByDefault)
        let capability = TestPluginManagementCapability(plugins: [enabled, disabled])
        capability.enabledIDs = ["enabled"]
        let viewModel = PluginManagementViewModel(
            capability: capability,
            docsCapability: PluginManagerDocsCapabilityAdapter(docs: nil)
        )

        viewModel.refresh()
        #expect(viewModel.filteredPlugins.map(\.id) == ["enabled", "disabled"])

        viewModel.statusFilter = .enabled
        #expect(viewModel.filteredPlugins.map(\.id) == ["enabled"])

        viewModel.statusFilter = .disabled
        #expect(viewModel.filteredPlugins.map(\.id) == ["disabled"])

        viewModel.searchText = "enabled"
        #expect(viewModel.filteredPlugins.isEmpty)
    }

    /// 插件 id 与旧版 PluginManagerPlugin 完全一致（保证状态存储兼容），
    /// 顺序与策略对齐旧版（order 90 / alwaysOn → required）。
    @Test
    func pluginMetadataMatchesLegacy() {
        let plugin = PluginPluginManager()
        #expect(plugin.id == "com.coffic.lumi.plugin.plugin-manager")
        #expect(plugin.order == 90)
        #expect(plugin.metadata.policy == .required)
        #expect(plugin.metadata.category == .system)
        #expect(plugin.metadata.stage == .stable)
    }

    /// 宿主可以指定插件自身的启用策略。
    ///
    /// 宿主若不希望这个插件进入内核（连同它贡献的「插件管理」设置入口一并
    /// 消失），传 `.disabled` —— 内核启动时会彻底排除它。
    @Test("可以指定插件自身的启用策略")
    func policyIsConfigurableByHost() {
        #expect(PluginPluginManager().metadata.policy == .required)
        #expect(PluginPluginManager(policy: .disabled).metadata.policy == .disabled)
        #expect(PluginPluginManager(policy: .alwaysOn).metadata.policy == .alwaysOn)
    }

    /// onReady 注册「插件管理」设置入口；onShutdown 撤回入口。
    ///
    /// 入口在 `onReady`（而非 `onBoot`）注册：`entryVisibility` 需要依据
    /// **全部**插件的策略判断，而 `onBoot` 阶段 order 更大的插件尚未注册。
    ///
    /// 这里显式传 `.always`：测试只关心入口的呈现细节（标题 / 图标 / 顺序），
    /// 不想让「宿主有无���配置插件」影响断言。
    @Test
    func onReadyRegistersSettingEntryAndShutdownRemoves() throws {
        let settings = DefaultSettingViewProviding()
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any SettingViewProviding).self, settings)
        try kernel.registerProvider(
            (any PluginManaging).self,
            DefaultPluginManager(kernel: kernel)
        )

        let plugin = PluginPluginManager(entryVisibility: .always)
        try plugin.onBoot(kernel: kernel)
        try plugin.onReady(kernel: kernel)
        #expect(settings.entries.contains { $0.id == "plugin-manager" })

        try plugin.onShutdown(kernel: kernel)
        #expect(!settings.entries.contains { $0.id == "plugin-manager" })
    }

    /// 设置入口的标题 / 图标 / 顺序与旧版 SettingsTabItem 对齐。
    @Test
    func entryUsesLegacyPresentation() throws {
        let settings = DefaultSettingViewProviding()
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any SettingViewProviding).self, settings)
        try kernel.registerProvider(
            (any PluginManaging).self,
            DefaultPluginManager(kernel: kernel)
        )

        let plugin = PluginPluginManager(entryVisibility: .always)
        try plugin.onBoot(kernel: kernel)
        try plugin.onReady(kernel: kernel)

        let entry = settings.entries.first { $0.id == "plugin-manager" }
        #expect(entry?.title == "插件管理")
        #expect(entry?.systemImage == "puzzlepiece.extension")
        #expect(entry?.order == 3)
    }

    /// 提示建议跟随「插件管理」设置入口：入口存在时注册，指向该入口。
    ///
    /// 提示建议的注册推迟到 `onReady`（入口可见性要等全部插件就绪才能判断），
    /// 所以这里要跑完整的 `onBoot` + `onReady`。
    @Test("浏览插件建议指向插件管理设置入口")
    func browseSuggestionTargetsPluginManagementEntry() throws {
        let settings = DefaultSettingViewProviding()
        let suggestions = DefaultPromptSuggestionProvider()
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any SettingViewProviding).self, settings)
        try kernel.registerProvider((any PromptSuggestionProviding).self, suggestions)
        try kernel.registerProvider(
            (any PluginManaging).self,
            DefaultPluginManager(kernel: kernel)
        )

        let plugin = PluginPluginManager(entryVisibility: .always)
        try plugin.onBoot(kernel: kernel)
        try plugin.onReady(kernel: kernel)

        let suggestion = suggestions.allSuggestions.first { $0.title == "浏览插件" }
        #expect(suggestion?.action == .openSettingsTab(PluginPluginManager.settingsEntryID))
    }

    /// 插件数量低于阈值时不显示搜索框，达到阈值才显示。
    @Test("插件数量低于 10 个时不显示搜索框")
    func searchBarHiddenBelowPluginCountThreshold() {
        let capability = TestPluginManagementCapability(
            plugins: (0..<9).map { TestPlugin(id: "plugin-\($0)", policy: .enabledByDefault) }
        )
        let viewModel = PluginManagementViewModel(
            capability: capability,
            docsCapability: PluginManagerDocsCapabilityAdapter(docs: nil)
        )

        viewModel.refresh()
        #expect(viewModel.plugins.count == 9)
        #expect(viewModel.showsSearchBar == false)

        capability.plugins.append(TestPlugin(id: "plugin-9", policy: .enabledByDefault))
        viewModel.refresh()
        #expect(viewModel.plugins.count == 10)
        #expect(viewModel.showsSearchBar == true)
    }

    /// 搜索框的显隐只看插件总数，不随筛选 / 搜索命中的条数变化，
    /// 否则用户一输入关键字搜索框就会消失，无法清空。
    @Test("搜索框显隐按插件总数判定，不随筛选结果变化")
    func searchBarVisibilityIgnoresFilters() {
        let capability = TestPluginManagementCapability(
            plugins: (0..<10).map { TestPlugin(id: "plugin-\($0)", policy: .enabledByDefault) }
        )
        let viewModel = PluginManagementViewModel(
            capability: capability,
            docsCapability: PluginManagerDocsCapabilityAdapter(docs: nil)
        )

        viewModel.refresh()
        #expect(viewModel.showsSearchBar)

        viewModel.searchText = "不存在的关键字"
        #expect(viewModel.filteredPlugins.isEmpty)
        #expect(viewModel.showsSearchBar)

        viewModel.searchText = ""
        viewModel.statusFilter = .enabled
        #expect(viewModel.filteredPlugins.isEmpty)
        #expect(viewModel.showsSearchBar)
    }

    /// 设置视图未注册时优雅降级：onBoot 不抛错、不贡献入口。
    @Test
    func onBootDegradesGracefullyWithoutSettingsProvider() throws {
        let kernel = KernelCoreContainer()
        let plugin = PluginPluginManager()
        try plugin.onBoot(kernel: kernel) // 不应抛错
        #expect(kernel.resolveProvider((any SettingViewProviding).self) == nil)
    }

    // MARK: - 启停失败反馈

    /// 启停失败时记录失败原因，供界面展示错误横幅。
    @Test("启停失败时记录失败原因")
    func enableFailureRecordsErrorMessage() async {
        let plugin = TestPlugin(id: "target", policy: .enabledByDefault)
        let capability = TestPluginManagementCapability(plugins: [plugin])
        capability.failingPluginIDs = ["target"]
        capability.lastErrorDescription = "启停失败：内核未就绪"
        let viewModel = PluginManagementViewModel(
            capability: capability,
            docsCapability: PluginManagerDocsCapabilityAdapter(docs: nil)
        )
        viewModel.refresh()

        viewModel.setEnabled(true, for: "target")
        await waitForPendingUpdates(viewModel)

        #expect(viewModel.errorMessage == "启停失败：内核未就绪")
    }

    /// 启停成功后清除上一次的失败原因。
    @Test("启停成功后清除错误原因")
    func enableSuccessClearsErrorMessage() async {
        let plugin = TestPlugin(id: "target", policy: .enabledByDefault)
        let capability = TestPluginManagementCapability(plugins: [plugin])
        capability.lastErrorDescription = "上一次的错误"
        let viewModel = PluginManagementViewModel(
            capability: capability,
            docsCapability: PluginManagerDocsCapabilityAdapter(docs: nil)
        )
        viewModel.refresh()

        viewModel.setEnabled(true, for: "target")
        await waitForPendingUpdates(viewModel)

        #expect(viewModel.errorMessage == nil)
    }

    /// 手动清除错误提示。
    @Test("可以手动清除错误提示")
    func clearErrorResetsMessage() {
        let capability = TestPluginManagementCapability(plugins: [])
        let viewModel = PluginManagementViewModel(
            capability: capability,
            docsCapability: PluginManagerDocsCapabilityAdapter(docs: nil)
        )
        viewModel.refresh()

        viewModel.setEnabled(true, for: "missing")
        viewModel.clearError()
        #expect(viewModel.errorMessage == nil)
    }
}

@MainActor
private final class TestPlugin: SuperPlugin {
    let id: String
    let metadata: PluginMetadata

    init(id: String, policy: PluginEnablePolicy) {
        self.id = id
        metadata = PluginMetadata(
            id: id,
            name: id,
            policy: policy
        )
    }
}

@MainActor
private final class TestPluginManagementCapability: PluginManagementCapability {
    var plugins: [any SuperPlugin]
    var enabledIDs: Set<String> = []

    /// 模拟最近一次启停失败的原因。
    var lastErrorDescription: String?

    /// 启停时返回失败的插件 id；为空表示全部成功。
    var failingPluginIDs: Set<String> = []

    init(plugins: [any SuperPlugin]) {
        self.plugins = plugins
    }

    var allPlugins: [any SuperPlugin] { plugins }

    func isEnabled(id: String) -> Bool {
        enabledIDs.contains(id)
    }

    func enablePlugin(id: String) async -> Bool {
        !failingPluginIDs.contains(id)
    }

    func disablePlugin(id: String) async -> Bool {
        !failingPluginIDs.contains(id)
    }

    func addObserver(
        _ callback: @escaping (PluginManagingEvent) -> Void
    ) -> any PluginManagingObserverHandle {
        TestPluginManagementObserverHandle()
    }
}

@MainActor
private final class TestPluginManagementObserverHandle: PluginManagingObserverHandle {
    func cancel() {}
}

/// 等待进行中的启停操作落地。
///
/// 启停由 ViewModel 内部派发 `Task { @MainActor }` 执行，断言前需要确保
/// 它已经结束，否则读到的是操作前的状态。
@MainActor
private func waitForPendingUpdates(_ viewModel: PluginManagementViewModel) async {
    let pluginIDs = viewModel.plugins.map(\.id)
    while pluginIDs.contains(where: { viewModel.isUpdating(pluginID: $0) }) || viewModel.isDisablingAll {
        await Task.yield()
    }
}
