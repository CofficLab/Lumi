import Foundation
import KernelCore
import ProviderNetwork
import ProviderProject
import ProviderRootView
import ProviderToast
import ProviderToolbar
import Testing
@testable import FactoryLumi2

@MainActor
@Suite("FactoryLumi2")
struct FactoryLumi2Tests {

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

        let project = factory.makeProjectProvider()
        let toast = factory.makeToastProvider()
        let network = factory.makeNetworkProvider()
        let toolbar = factory.makeToolbarProvider()
        let rootView = factory.makeRootViewProvider()

        #expect(project is DefaultProjectProviding)
        #expect(toast is DefaultToastProviding)
        #expect(network is DefaultNetworkProviding)
        #expect(toolbar is DefaultToolbarProviding)
        #expect(rootView is DefaultRootViewProviding)
    }
}
