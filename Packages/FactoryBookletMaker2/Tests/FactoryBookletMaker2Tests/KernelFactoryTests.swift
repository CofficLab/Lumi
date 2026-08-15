import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderNetwork
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
