import Foundation
import KernelCore
import ProviderActivityBar
import ProviderNetwork
import ProviderProject
import ProviderRailView
import ProviderRootView
import ProviderSettingView
import ProviderStorage
import ProviderToast
import ProviderToolbar
import SwiftUI
import Testing
@testable import FactoryLumi2

@MainActor
@Suite("FactoryLumi2")
struct FactoryLumi2Tests {

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
        #expect(kernel.isPluginRegistered(id: "com.coffic.lumi.plugin.device"))

        let settings = kernel.resolveProvider((any SettingViewProviding).self)
        #expect(settings?.entries.contains(where: { $0.id == "general" }) == true)
        #expect(settings?.entries.contains(where: { $0.id == "device" }) == true)
    }
}
