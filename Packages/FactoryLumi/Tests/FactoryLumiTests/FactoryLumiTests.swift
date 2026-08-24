import Foundation
import KernelCore
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderConversation
import ProviderDocsView
import ProviderLogo
import ProviderMenuBar
import ProviderNetwork
import ProviderProject
import ProviderRailView
import ProviderRootView
import ProviderSettingView
import ProviderStorage
import ProviderTheme
import ProviderToast
import ProviderToolbar
import ProviderToolManager
import ProviderLLMManager
import KitLLM
import ProviderMessage
import PluginConversationManager
import SwiftUI
import Testing
@testable import FactoryLumi

@MainActor
@Suite("FactoryLumi")
struct FactoryLumiTests {

    private final class AdditionalPlugin: SuperPlugin {
        let id = "test.additional-plugin"
        let metadata = PluginMetadata(
            id: "test.additional-plugin",
            name: "Additional test plugin",
            description: "",
            category: .general,
            stage: .stable,
            policy: .alwaysOn
        )
    }

    @Test("SelectedPluginFactory 仅产出白名单插件并保持原目录顺序")
    func selectedPluginFactoryFiltersTheCatalog() {
        let factory = SelectedPluginFactory(
            allowedPluginIDs: [
                "com.coffic.lumi.plugin.command",
                "com.coffic.lumi.plugin.toast",
            ]
        )

        #expect(factory.makePlugins().map(\.id) == [
            "com.coffic.lumi.plugin.command",
            "com.coffic.lumi.plugin.toast",
        ])
    }

    /// 测试用最小 LLM 供应商：回显最后一条用户消息。
    @MainActor
    private final class EchoManagedProvider: ManagedLLMProvider {
        let providerInfo: LLMProviderInfo

        init(id: String = "echo") {
            providerInfo = LLMProviderInfo(
                id: id,
                displayName: id,
                defaultModel: "echo-1",
                models: [LLMModelInfo(id: "echo-1")]
            )
        }

        var providerID: String { providerInfo.id }

        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            let text = request.messages.last?.content ?? ""
            return LLMResponse(content: "echo:\(text)", model: request.model)
        }
    }

    @Test("makeKernel 启动 ModelSelectorPlugin 并注册 Action Bar 模型选择按钮")
    func makeKernelRegistersModelSelectorActionBarButton() throws {
        let kernel = try KernelFactory.makeKernel()

        // 插件本体已启动（保持旧 ID）。
        #expect(kernel.resolvePlugin(id: "com.coffic.lumi.plugin.model-selector") != nil)

        // Action Bar leading 位置的模型选择按钮已注册。
        let chat = kernel.resolveProvider((any ChatSectionProviding).self) as? DefaultChatSectionProviding
        let barItemIDs = chat?.barItems.map { $0.id } ?? []
        #expect(barItemIDs.contains("com.coffic.lumi.plugin.model-selector.action-bar-button"))
    }

    @Test("makeKernel 创建内核并注册默认 StorageProviding")
    func makeKernelRegistersDefaultStorageProvider() throws {
        let kernel = try KernelFactory.makeKernel()

        let resolved: (any StorageProviding)? = kernel.resolveProvider((any StorageProviding).self)
        #expect(resolved != nil)
        #expect(!resolved!.dataRootDirectory.path.isEmpty)
    }

    @Test("makeKernel 创建内核并注册默认 ProjectProviding")
    func makeKernelRegistersDefaultProjectProviding() throws {
        let kernel = try KernelFactory.makeKernel()

        let resolved: (any ProjectProviding)? = kernel.resolveProvider((any ProjectProviding).self)
        #expect(resolved != nil)
        #expect(resolved is DefaultProjectProviding)
    }

    @Test("makeKernel 创建内核并注册默认 ConversationManaging")
    func makeKernelRegistersDefaultConversationManaging() throws {
        let kernel = try KernelFactory.makeKernel()

        let resolved: (any ConversationManaging)? = kernel.resolveProvider((any ConversationManaging).self)
        #expect(resolved != nil)
        // 默认内存实现已被 ConversationManagerPlugin 替换为 SwiftData 持久化实现。
        #expect(resolved is ConversationManager)

        // 复刻能力冒烟：创建 → 选中 → 查询（结束后删除，避免污染真实用户数据）。
        guard let id = try resolved?.createConversation(title: "集成验证", projectPath: nil, providerID: nil, modelName: nil) else {
            Issue.record("创建对话失败")
            return
        }
        #expect(resolved?.selectedConversationID == id)
        #expect(resolved?.currentTitle == "集成验证")
        resolved?.deleteConversation(id: id)
    }

    @Test("makeKernel 创建内核并注册默认 ToastProviding")
    func makeKernelRegistersDefaultToastProviding() throws {
        let kernel = try KernelFactory.makeKernel()

        let resolved: (any ToastProviding)? = kernel.resolveProvider((any ToastProviding).self)
        #expect(resolved != nil)
    }

    @Test("makeKernel 创建内核并注册默认 NetworkProviding")
    func makeKernelRegistersDefaultNetworkProviding() throws {
        let kernel = try KernelFactory.makeKernel()

        let resolved: (any NetworkProviding)? = kernel.resolveProvider((any NetworkProviding).self)
        #expect(resolved != nil)
    }

    @Test("makeKernel 创建内核并注册默认 ToolbarProviding")
    func makeKernelRegistersDefaultToolbarProviding() throws {
        let kernel = try KernelFactory.makeKernel()

        let resolved: (any ToolbarProviding)? = kernel.resolveProvider((any ToolbarProviding).self)
        #expect(resolved != nil)
        #expect(resolved is DefaultToolbarProviding)
    }

    @Test("makeKernel 创建内核并注册默认 RootViewProviding")
    func makeKernelRegistersDefaultRootViewProviding() throws {
        let kernel = try KernelFactory.makeKernel()

        let resolved: (any RootViewProviding)? = kernel.resolveProvider((any RootViewProviding).self)
        #expect(resolved != nil)
        #expect(resolved is DefaultRootViewProvider)
    }

    @Test("makeKernel 创建内核并注册默认 ActivityBarProviding")
    func makeKernelRegistersDefaultActivityBarProviding() throws {
        let kernel = try KernelFactory.makeKernel()

        let resolved: (any ActivityBarProviding)? = kernel.resolveProvider((any ActivityBarProviding).self)
        #expect(resolved != nil)
        #expect(!resolved!.items.isEmpty)
    }

    @Test("默认内容插件注册 ActivityBar 入口且设备入口初始激活")
    func defaultContentPluginsRegisterActivityBarEntries() throws {
        let kernel = try KernelFactory.makeKernel()
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)

        #expect(activityBar?.items.map(\.id) == [
            "com.coffic.lumi.plugin.chat-panel.entry",
            "com.coffic.lumi.plugin.device-info.entry",
            "com.coffic.lumi.plugin.hosts-manager.entry",
            "com.coffic.lumi.plugin.app-icon-designer.entry",
            "com.coffic.lumi.plugin.app-store-promo-designer.entry",
            "com.coffic.lumi.plugin.mind-map.entry",
            "com.coffic.lumi.plugin.resume-designer.entry",
            "com.coffic.lumi.plugin.disk-manager.entry",
            "com.coffic.lumi.plugin.white-noise.entry",
            "com.coffic.lumi.plugin.video-converter.entry",
        ])
        #expect(activityBar?.activeItemID == "com.coffic.lumi.plugin.chat-panel.entry")

        activityBar?.activateItem(id: "com.coffic.lumi.plugin.video-converter.entry")
        #expect(activityBar?.activeItemID == "com.coffic.lumi.plugin.video-converter.entry")

        let rail = kernel.resolveProvider((any RailViewProviding).self)
        #expect(rail?.activeGroupID == "com.coffic.lumi.plugin.video-converter")
        #expect(rail?.activeTabID == nil)

        activityBar?.activateItem(id: "com.coffic.lumi.plugin.app-icon-designer.entry")
        #expect(rail?.activeGroupID == "com.coffic.lumi.plugin.app-icon-designer")
        #expect(rail?.activeTabID == "app-icon-designer.documents")
    }

    @Test("makeKernel 创建内核并注册默认 RailViewProviding")
    func makeKernelRegistersDefaultRailViewProviding() throws {
        let kernel = try KernelFactory.makeKernel()

        let resolved: (any RailViewProviding)? = kernel.resolveProvider((any RailViewProviding).self)
        #expect(resolved != nil)
        #expect(resolved is DefaultRailViewProviding)
    }

    @Test("makeKernel 创建内核并注册默认 SettingViewProviding")
    func makeKernelRegistersDefaultSettingViewProviding() throws {
        let kernel = try KernelFactory.makeKernel()

        let resolved: (any SettingViewProviding)? = kernel.resolveProvider((any SettingViewProviding).self)
        #expect(resolved != nil)
    }

    @Test("内核可解析出 ProjectProviding 并正常使用")
    func kernelResolvesUsableProvider() async throws {
        let kernel = try KernelFactory.makeKernel()

        let project: (any ProjectProviding)? = kernel.resolveProvider((any ProjectProviding).self)
        try await project?.openProject(at: "/Users/me/Code/Lumi")

        #expect(project?.currentProject?.name == "Lumi")
        #expect(project?.currentProject?.path == "/Users/me/Code/Lumi")
    }

    @Test("ProviderFactory 产出默认 Provider 实现")
    func providerFactoryMakesDefaults() {
        let factory = DefaultProviderFactory()

        let storage = factory.makeStorageProvider()
        let project = factory.makeProjectProvider()
        let toast = factory.makeToastProvider()
        let network = factory.makeNetworkProvider()
        let toolbar = factory.makeToolbarProvider()
        let rootView = factory.makeRootViewProvider()
        let activityBar = factory.makeActivityBarProvider()
        let railView = factory.makeRailViewProvider()
        let settingView = factory.makeSettingViewProvider()

        #expect(storage is DefaultStorageProvider)
        #expect(project is DefaultProjectProviding)
        #expect(toast is DefaultToastProviding)
        #expect(network is DefaultNetworkProviding)
        #expect(toolbar is DefaultToolbarProviding)
        #expect(rootView is DefaultRootViewProvider)
        #expect(activityBar is DefaultActivityBarProviding)
        #expect(railView is DefaultRailViewProviding)
        #expect(settingView is DefaultSettingViewProviding)
    }

    @Test("makeMainView 返回可渲染的根视图")
    func makeMainViewReturnsRootView() throws {
        let view = try KernelFactory.makeMainView()

        #expect(type(of: view) == AnyView.self)
    }

    @Test("makeSettingsView 返回可渲染的设置视图")
    func makeSettingsViewReturnsSettingsView() throws {
        let view = try KernelFactory.makeSettingsView()

        #expect(type(of: view) == AnyView.self)
    }

    @Test("makeKernel 启动插件后设置视图含「通用」与「设备信息」入口")
    func makeKernelBootsPluginsAndRegistersEntries() throws {
        let kernel = try KernelFactory.makeKernel()

        #expect(kernel.isPluginRegistered(id: "com.coffic.lumi.plugin.setting-general"))
        #expect(kernel.isPluginRegistered(id: "com.coffic.lumi.plugin.device-info"))

        let settings = kernel.resolveProvider((any SettingViewProviding).self)
        #expect(settings?.entries.contains(where: { $0.id == "general" }) == true)
    }

    @Test("默认目录复刻旧版 Project RAG 插件与 search_code 工具")
    func defaultCatalogIncludesProjectRAG() throws {
        let kernel = try KernelFactory.makeKernel()

        #expect(kernel.isPluginRegistered(id: "com.coffic.lumi.plugin.project.rag"))
        let tools = kernel.resolveProvider((any ToolManagerProviding).self)
        #expect(tools?.tool(named: "search_code") != nil)
    }

    @Test("makeKernel 启动 SettingsToolbarPlugin 后工具栏含设置按钮")
    func makeKernelBootsToolbarSettingsPlugin() throws {
        let kernel = try KernelFactory.makeKernel()

        #expect(kernel.isPluginRegistered(id: "com.coffic.lumi.plugin.toolbar-settings"))

        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        #expect(toolbar?.toolbarItems.contains(where: { $0.id == "settings" }) == true)
        #expect(toolbar?.toolbarItems.first(where: { $0.id == "settings" })?.placement == .trailing)
    }

    @Test("makeKernel 注册 DocsViewProviding 且 DevicePlugin 已贡献文档")
    func makeKernelRegistersDocsViewProviding() throws {
        let kernel = try KernelFactory.makeKernel()

        let docs = kernel.resolveProvider((any DocsViewProviding).self)
        #expect(docs != nil)
        #expect(docs is DefaultDocsViewProviding)
    }

    @Test("makeKernel 注册 MenuBarProviding 且 DevicePlugin 已贡献菜单栏")
    func makeKernelRegistersMenuBarProviding() throws {
        let kernel = try KernelFactory.makeKernel()

        let menuBar = kernel.resolveProvider((any MenuBarProviding).self)
        #expect(menuBar != nil)
    }

    @Test("makeKernel 创建内核并注册默认 LogoProviding")
    func makeKernelRegistersDefaultLogoProviding() throws {
        let kernel = try KernelFactory.makeKernel()

        let resolved: (any LogoProviding)? = kernel.resolveProvider((any LogoProviding).self)
        #expect(resolved != nil)
        #expect(resolved?.highestPriorityLogoItem != nil)
    }

    @Test("ProviderFactory 产出默认 LogoProviding 实现")
    func providerFactoryMakesDefaultLogo() {
        let factory = DefaultProviderFactory()

        let logo = factory.makeLogoProvider()

        #expect(logo is DefaultLogoProviding)
    }

    @Test("装配后的 LogoProviding 注册 LogoCofficPlugin 贡献并可查询最高优先级")
    func kernelLogoProviderRegistersAndQueries() throws {
        let kernel = try KernelFactory.makeKernel()

        let logo = kernel.resolveProvider((any LogoProviding).self)
        #expect(logo != nil)

        // 默认已由 LogoCofficPlugin 贡献 Coffic Logo
        #expect(logo?.highestPriorityLogoItem?.id == "com.lumi.plugin.logo-coffic")

        // 注册更高优先级 Logo 后成为最高优先级
        logo?.registerLogoItem(
            LogoItem(id: "test.logo", order: 999) { _ in
                Image(systemName: "circle")
            }
        )
        #expect(logo?.highestPriorityLogoItem?.id == "test.logo")

        // 注销后回退到下一个贡献者（Coffic Logo）
        logo?.unregisterLogoItem(id: "test.logo")
        #expect(logo?.highestPriorityLogoItem?.id == "com.lumi.plugin.logo-coffic")
    }

    @Test("makeKernel 启动 ThemePackPlugin 后注册全部复刻主题")
    func makeKernelBootsThemePackAndRegistersThemes() throws {
        let kernel = try KernelFactory.makeKernel()

        #expect(kernel.isPluginRegistered(id: "com.coffic.lumi.plugin.theme-pack"))

        let theme = kernel.resolveProvider((any ThemeProviding).self)
        #expect(theme != nil)

        // 内置 3 个（System/Dark/Light）+ 复刻 19 个 = 22 个。
        #expect(theme?.themes.count == 22)

        // 复刻主题 id 与旧版主题插件一致。
        for id in ["lumi", "midnight", "sky", "aurora", "nebula", "void",
                   "spring", "summer", "autumn", "winter", "github", "orchard",
                   "mountain", "vscode-auto", "vscode-dark", "vscode-light",
                   "river", "one-dark", "dracula"] {
            #expect(theme?.themes.contains(where: { $0.id == id }) == true, "缺少复刻主题 \(id)")
        }

        // 切换复刻主题（如 Dracula）应成功。
        try theme?.selectTheme(id: "dracula")
        #expect(theme?.selectedThemeId == "dracula")
    }

    @Test("makeKernel 注册 ThemePackPlugin 外观设置入口")
    func makeKernelRegistersAppearanceSettingEntry() throws {
        let kernel = try KernelFactory.makeKernel()

        let settings = kernel.resolveProvider((any SettingViewProviding).self)
        #expect(settings?.entries.contains(where: { $0.id == "appearance" }) == true)
        #expect(settings?.entries.first(where: { $0.id == "appearance" })?.title == "外观")

        // 详情视图可渲染（不崩溃）。
        let detail = settings?.entries.first(where: { $0.id == "appearance" })?.makeDetailView()
        #expect(detail != nil)
    }

    @Test("宿主可注入附加插件而无需修改默认插件目录")
    func makeKernelAcceptsAdditionalPlugins() throws {
        let kernel = try KernelFactory.makeKernel(additionalPlugins: [AdditionalPlugin()])

        #expect(kernel.isPluginRegistered(id: "test.additional-plugin"))
        #expect(kernel.lifecycleState == .running)
    }

    @Test("停止内核会撤回默认插件写入共享 Provider 的贡献并支持重启")
    func stopWithdrawsContributionsAndSupportsRestart() throws {
        let kernel = try KernelFactory.makeKernel()

        try kernel.stop()

        #expect(kernel.resolveProvider((any SettingViewProviding).self)?.entries.isEmpty == true)
        #expect(kernel.resolveProvider((any DocsViewProviding).self)?.aboutEntries.isEmpty == true)
        #expect(kernel.resolveProvider((any MenuBarProviding).self)?.contentItems.isEmpty == true)
        #expect(kernel.resolveProvider((any LogoProviding).self)?.highestPriorityLogoItem == nil)
        #expect(kernel.resolveProvider((any ToolbarProviding).self)?.toolbarItems.isEmpty == true)
        #expect(kernel.resolveProvider((any ActivityBarProviding).self)?.items.isEmpty == true)
        #expect(kernel.resolveProvider((any ThemeProviding).self)?.themes.count == 3)

        try kernel.start(plugins: DefaultPluginFactory().makePlugins())
        #expect(kernel.lifecycleState == .running)
        #expect(kernel.resolveProvider((any ThemeProviding).self)?.themes.count == 22)
        #expect(kernel.resolveProvider((any ActivityBarProviding).self)?.items.count == 10)
    }

    @Test("makeKernel 注册默认 LLMManaging")
    func makeKernelRegistersDefaultLLMProviderManager() throws {
        let kernel = try KernelFactory.makeKernel()

        let manager: (any LLMManaging)? = kernel.resolveProvider((any LLMManaging).self)
        #expect(manager != nil)
        // 20 个 PluginLLMProviderXXX 插件在启动时注册全部 27 个内建供应商。
        #expect(manager?.providerCount == 27)
        #expect(manager?.providerID == "llm-provider-manager")
    }

    @Test("ProviderFactory 产出默认 LLMManaging 实现")
    func providerFactoryMakesDefaultLLMProviderManager() {
        let factory = DefaultProviderFactory()

        let manager = factory.makeLLMProviderManagerProvider()

        #expect(manager is DefaultLLMProviderManagerProviding)
    }

    @Test("内核装配后：注册供应商进管理器即可经管理器路由发送")
    func kernelRoutesThroughRegisteredProvider() async throws {
        let kernel = try KernelFactory.makeKernel()
        let manager = kernel.resolveProvider((any LLMManaging).self)
        #expect(manager != nil)

        try manager?.register(EchoManagedProvider(id: "echo"))
        // 启动时已选中内建列表首项 OpenAI；切到 echo 供应商再发送。
        manager?.select(providerID: "echo", model: nil)
        let response = try await manager?.complete(
            LLMRequest(
                conversationID: UUID(),
                messages: [LLMMessage(role: .user, content: "hi")]
            )
        )

        #expect(response?.content == "echo:hi")
        #expect(response?.model == "echo-1")
    }
}
