import KernelCore
import ProviderActivityBar
import ProviderCommand
import ProviderContentView
import ProviderDocsView
import ProviderLogo
import ProviderRailView
import ProviderRootView
import ProviderSettingView
import ProviderStorage
import ProviderTheme
import ProviderToolbar
import PluginSettingView
import Testing
@testable import FactoryBookletMaker

/// KernelFactory 装配逻辑的测试：makeKernel 注册 BookletMaker 所需 Provider，
/// 主视图与设置视图组装不崩溃。
@Suite("KernelFactory")
@MainActor
struct KernelFactoryTests {

    // MARK: - makeKernel

    @Test("makeKernel 注册 BookletMaker 所需 Provider")
    func makeKernelRegistersAllProviders() throws {
        let kernel = try KernelFactory.makeKernel()

        #expect(kernel.registeredProviderCount == 11)
        #expect(kernel.resolveProvider((any StorageProviding).self) != nil)
        #expect(kernel.resolveProvider((any ThemeProviding).self) != nil)
        #expect(kernel.resolveProvider((any CommandProviding).self) != nil)
        #expect(kernel.resolveProvider((any ContentViewProviding).self) != nil)
        #expect(kernel.resolveProvider((any DocsViewProviding).self) != nil)
        #expect(kernel.resolveProvider((any LogoProviding).self) != nil)
        #expect(kernel.resolveProvider((any ToolbarProviding).self) != nil)
        #expect(kernel.resolveProvider((any RootViewProviding).self) != nil)
        #expect(kernel.resolveProvider((any ActivityBarProviding).self) != nil)
        #expect(kernel.resolveProvider((any RailViewProviding).self) != nil)
        let settings = kernel.resolveProvider((any SettingViewProviding).self)
        #expect(settings != nil)
        #expect(settings is SettingViewManager)
        let themes = kernel.resolveProvider((any ThemeProviding).self)
        #expect(themes?.themes.count == 22)
        #expect(themes?.themes.contains(where: { $0.id == "dracula" }) == true)
        #expect(settings?.entries.contains(where: { $0.id == "appearance" }) == true)
        #expect(kernel.resolveProvider((any RailViewProviding).self)?.tabs.contains(where: {
            $0.id == "booklet-maker.sidebar"
        }) == true)
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

    @Test("共享内核可同时组装主窗口与设置窗口")
    func sharedKernelAssemblesBothViews() throws {
        let kernel = try KernelFactory.makeKernel()
        _ = try KernelFactory.makeMainView(kernel: kernel)
        _ = try KernelFactory.makeSettingsView(kernel: kernel)
    }
}

/// 工厂默认实现的测试：专用宿主必须装配 BookletMaker 插件。
@Suite("Default Factories")
@MainActor
struct DefaultFactoryTests {

    @Test("DefaultPluginFactory 产出 BookletMaker 插件")
    func defaultPluginsIncludeBookletMaker() {
        let plugins = DefaultPluginFactory().makePlugins()
        #expect(plugins.count == 8)
        #expect(plugins.contains(where: { $0.id == "com.coffic.lumi.plugin.setting-view" }))
        #expect(plugins.contains(where: { $0.id == "com.coffic.lumi.plugin.logo-manager" }))
        #expect(plugins.contains(where: { $0.id == "com.coffic.lumi.plugin.theme-pack" }))
        #expect(!plugins.contains(where: { $0.id.contains("activity-heatmap") }))
        #expect(!plugins.contains(where: { $0.id.contains("llm") }))
        let bookletMaker = plugins.first(where: { $0.id == "com.coffic.lumi.plugin.booklet-maker" })
        #expect(bookletMaker?.metadata.policy == .required)
    }
}
