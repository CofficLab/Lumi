import Foundation
import KernelCore
import ProviderActivityBar
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
import SwiftUI
import Testing
@testable import FactoryLumi2

@MainActor
@Suite("FactoryLumi2")
struct FactoryLumi2Tests {

    private final class AdditionalPlugin: SuperPlugin {
        let id = "test.additional-plugin"
    }

    @Test("makeKernel 创建内核并注册默认 StorageProviding")
    func makeKernelRegistersDefaultStorageProviding() throws {
        let kernel = try KernelFactory.makeKernel()

        let resolved: (any StorageProviding)? = kernel.resolveProvider((any StorageProviding).self)
        #expect(resolved != nil)
        #expect(resolved is DefaultStorageProviding)
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
        #expect(resolved is DefaultConversationManaging)

        // 复刻能力冒烟：创建 → 选中 → 查询。
        let id = try resolved?.createConversation(title: "集成验证", projectPath: nil, providerID: nil, modelName: nil)
        #expect(id != nil)
        #expect(resolved?.selectedConversationID == id)
        #expect(resolved?.currentTitle == "集成验证")
    }

    @Test("makeKernel 创建内核并注册默认 ToastProviding")
    func makeKernelRegistersDefaultToastProviding() throws {
        let kernel = try KernelFactory.makeKernel()

        let resolved: (any ToastProviding)? = kernel.resolveProvider((any ToastProviding).self)
        #expect(resolved != nil)
        #expect(resolved is DefaultToastProviding)
    }

    @Test("makeKernel 创建内核并注册默认 NetworkProviding")
    func makeKernelRegistersDefaultNetworkProviding() throws {
        let kernel = try KernelFactory.makeKernel()

        let resolved: (any NetworkProviding)? = kernel.resolveProvider((any NetworkProviding).self)
        #expect(resolved != nil)
        #expect(resolved is DefaultNetworkProviding)
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
        #expect(resolved is DefaultRootViewProviding)
    }

    @Test("makeKernel 创建内核并注册默认 ActivityBarProviding")
    func makeKernelRegistersDefaultActivityBarProviding() throws {
        let kernel = try KernelFactory.makeKernel()

        let resolved: (any ActivityBarProviding)? = kernel.resolveProvider((any ActivityBarProviding).self)
        #expect(resolved != nil)
        #expect(resolved is DefaultActivityBarProviding)
    }

    @Test("默认内容插件注册 ActivityBar 入口且设备入口初始激活")
    func defaultContentPluginsRegisterActivityBarEntries() throws {
        let kernel = try KernelFactory.makeKernel()
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)

        #expect(activityBar?.items.map(\.id) == [
            "com.coffic.lumi.plugin.device-info.entry",
            "com.coffic.lumi.plugin.app-icon-designer.entry",
            "com.coffic.lumi.plugin.white-noise.entry",
            "com.coffic.lumi.plugin.video-converter.entry",
        ])
        #expect(activityBar?.activeItemID == "com.coffic.lumi.plugin.device-info.entry")

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
        #expect(resolved is DefaultSettingViewProviding)
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

        #expect(storage is DefaultStorageProviding)
        #expect(project is DefaultProjectProviding)
        #expect(toast is DefaultToastProviding)
        #expect(network is DefaultNetworkProviding)
        #expect(toolbar is DefaultToolbarProviding)
        #expect(rootView is DefaultRootViewProviding)
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
        #expect(settings?.entries.contains(where: { $0.id == "com.coffic.lumi.plugin.device-info.memory-settings" }) == true)
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
        #expect(docs?.aboutEntries.contains(where: { $0.id == "com.coffic.lumi.plugin.device-info" }) == true)
        #expect(docs?.manualEntries.contains(where: { $0.id == "com.coffic.lumi.plugin.device-info" }) == true)
    }

    @Test("makeKernel 注册 MenuBarProviding 且 DevicePlugin 已贡献菜单栏")
    func makeKernelRegistersMenuBarProviding() throws {
        let kernel = try KernelFactory.makeKernel()

        let menuBar = kernel.resolveProvider((any MenuBarProviding).self)
        #expect(menuBar != nil)
        #expect(menuBar is DefaultMenuBarProviding)
        #expect(menuBar?.contentItems.contains(where: { $0.id.hasSuffix(".metrics") }) == true)
        #expect(menuBar?.popupItems.contains(where: { $0.id.hasSuffix(".cpu") }) == true)
        #expect(menuBar?.popupItems.contains(where: { $0.id.hasSuffix(".memory") }) == true)
    }

    @Test("makeKernel 创建内核并注册默认 LogoProviding")
    func makeKernelRegistersDefaultLogoProviding() throws {
        let kernel = try KernelFactory.makeKernel()

        let resolved: (any LogoProviding)? = kernel.resolveProvider((any LogoProviding).self)
        #expect(resolved != nil)
        #expect(resolved is DefaultLogoProviding)
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
        #expect(kernel.resolveProvider((any ActivityBarProviding).self)?.items.count == 4)
    }
}
