import Foundation
import KernelCore
import ProviderNetwork
import ProviderProject
import ProviderToast
import ProviderWindow
import SwiftUI
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

    @Test("makeKernel 支持注入自定义 ProjectProviding 实现")
    func makeKernelAcceptsCustomProvider() throws {
        let provider = CustomProjectProvider()
        let kernel = try KernelFactory.makeKernel(projectProvider: provider)

        let resolved: (any ProjectProviding)? = kernel.resolveProvider((any ProjectProviding).self)
        #expect(resolved as? CustomProjectProvider === provider)
    }

    @Test("makeKernel 支持注入自定义 ToastProviding 实现")
    func makeKernelAcceptsCustomToastProvider() throws {
        let provider = CustomToastProvider()
        let kernel = try KernelFactory.makeKernel(toastProvider: provider)

        let resolved: (any ToastProviding)? = kernel.resolveProvider((any ToastProviding).self)
        #expect(resolved as? CustomToastProvider === provider)
    }

    @Test("内核可解析出 ProjectProviding 并正常使用")
    func kernelResolvesUsableProvider() async throws {
        let kernel = try KernelFactory.makeKernel()

        let project: (any ProjectProviding)? = kernel.resolveProvider((any ProjectProviding).self)
        try await project?.openProject(at: "/Users/me/Code/Lumi")

        #expect(project?.currentProject?.name == "Lumi")
        #expect(project?.currentProject?.path == "/Users/me/Code/Lumi")
    }

    @Test("makeKernel 创建内核并注册默认 NetworkProviding")
    func makeKernelRegistersDefaultNetworkProviding() throws {
        let kernel = try KernelFactory.makeKernel()

        let resolved: (any NetworkProviding)? = kernel.resolveProvider((any NetworkProviding).self)
        #expect(resolved != nil)
        #expect(resolved is DefaultNetworkProviding)
    }

    @Test("makeKernel 支持注入自定义 NetworkProviding 实现")
    func makeKernelAcceptsCustomNetworkProvider() throws {
        let provider = CustomNetworkProvider()
        let kernel = try KernelFactory.makeKernel(networkProvider: provider)

        let resolved: (any NetworkProviding)? = kernel.resolveProvider((any NetworkProviding).self)
        #expect(resolved as? CustomNetworkProvider === provider)
    }

    @Test("makeKernel 创建内核并注册默认 WindowProviding")
    func makeKernelRegistersDefaultWindowProviding() throws {
        let kernel = try KernelFactory.makeKernel()

        let resolved: (any WindowProviding)? = kernel.resolveProvider((any WindowProviding).self)
        #expect(resolved != nil)
        #expect(resolved is DefaultWindowProviding)
    }

    @Test("makeKernel 支持注入自定义 WindowProviding 实现")
    func makeKernelAcceptsCustomWindowProvider() throws {
        let provider = CustomWindowProvider()
        let kernel = try KernelFactory.makeKernel(windowProvider: provider)

        let resolved: (any WindowProviding)? = kernel.resolveProvider((any WindowProviding).self)
        #expect(resolved as? CustomWindowProvider === provider)
    }

    @Test("ProviderFactory 产出默认 Provider 实现")
    func providerFactoryMakesDefaults() {
        let factory = DefaultProviderFactory()

        let project = factory.makeProjectProvider()
        let toast = factory.makeToastProvider()
        let network = factory.makeNetworkProvider()
        let window = factory.makeWindowProvider()

        #expect(project is DefaultProjectProviding)
        #expect(toast is DefaultToastProviding)
        #expect(network is DefaultNetworkProviding)
        #expect(window is DefaultWindowProviding)
    }

    @Test("makeKernel(providers:) 使用自定义 ProviderFactory 注册")
    func makeKernelWithCustomFactory() throws {
        let custom = CustomProviderFactory()
        let kernel = try KernelFactory.makeKernel(providers: custom)

        let project: (any ProjectProviding)? = kernel.resolveProvider((any ProjectProviding).self)
        let toast: (any ToastProviding)? = kernel.resolveProvider((any ToastProviding).self)
        let network: (any NetworkProviding)? = kernel.resolveProvider((any NetworkProviding).self)
        let window: (any WindowProviding)? = kernel.resolveProvider((any WindowProviding).self)

        #expect(project is CustomProjectProvider)
        #expect(toast is CustomToastProvider)
        #expect(network is CustomNetworkProvider)
        #expect(window is CustomWindowProvider)
    }

    /// 测试用自定义工厂：覆盖所有 Provider 的产出。
    private struct CustomProviderFactory: ProviderFactory {
        func makeProjectProvider() -> any ProjectProviding {
            CustomProjectProvider()
        }

        func makeToastProvider() -> any ToastProviding {
            CustomToastProvider()
        }

        func makeNetworkProvider() -> any NetworkProviding {
            CustomNetworkProvider()
        }

        func makeWindowProvider() -> any WindowProviding {
            CustomWindowProvider()
        }
    }

    /// 测试用自定义项目实现。
    private final class CustomProjectProvider: ProjectProviding {
        var currentProject: ProjectInfo?
        var projects: [ProjectInfo] = []

        func openProject(at path: String) async throws {
            currentProject = ProjectInfo(name: "custom", path: path)
        }

        func closeProject() async {}

        func refreshProjects() async throws {}
    }

    /// 测试用自定义 Toast 实现。
    private final class CustomToastProvider: ToastProviding {
        var received: [LumiToast] = []

        func show(_ toast: LumiToast) {
            received.append(toast)
        }
    }

    /// 测试用自定义网络实现。
    private final class CustomNetworkProvider: NetworkProviding {
        func request(_ request: HTTPRequest) async throws -> HTTPResponse {
            HTTPResponse(statusCode: 200, headers: [:], body: Data(), url: request.url)
        }

        func stream(
            _ request: HTTPRequest,
            onResponse: @Sendable @escaping (HTTPResponseMetadata) async -> Void,
            onChunk: @Sendable @escaping (Data) async -> Bool
        ) async throws {
            await onResponse(HTTPResponseMetadata(statusCode: 200, headers: [:], url: request.url))
        }
    }

    /// 测试用自定义窗口实现。
    private final class CustomWindowProvider: WindowProviding {
        func makeRootView() -> AnyView {
            AnyView(Text("custom window"))
        }
    }
}
