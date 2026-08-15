import Foundation
import KernelCore
import ProviderProject
import ProviderToast
import Testing
@testable import FactoryLumi2

@MainActor
@Suite("FactoryLumi2")
struct FactoryLumi2Tests {

    @Test("makeKernel 创建内核并注册默认 ProjectProviding")
    func makeKernelRegistersDefaultProjectProviding() throws {
        let kernel = try FactoryLumi2.makeKernel()

        let resolved: (any ProjectProviding)? = kernel.resolveProvider((any ProjectProviding).self)
        #expect(resolved != nil)
        #expect(resolved is DefaultProjectProviding)
    }

    @Test("makeKernel 创建内核并注册默认 ToastProviding")
    func makeKernelRegistersDefaultToastProviding() throws {
        let kernel = try FactoryLumi2.makeKernel()

        let resolved: (any ToastProviding)? = kernel.resolveProvider((any ToastProviding).self)
        #expect(resolved != nil)
        #expect(resolved is DefaultToastProviding)
    }

    @Test("makeKernel 支持注入自定义 ProjectProviding 实现")
    func makeKernelAcceptsCustomProvider() throws {
        let provider = CustomProjectProvider()
        let kernel = try FactoryLumi2.makeKernel(projectProvider: provider)

        let resolved: (any ProjectProviding)? = kernel.resolveProvider((any ProjectProviding).self)
        #expect(resolved as? CustomProjectProvider === provider)
    }

    @Test("makeKernel 支持注入自定义 ToastProviding 实现")
    func makeKernelAcceptsCustomToastProvider() throws {
        let provider = CustomToastProvider()
        let kernel = try FactoryLumi2.makeKernel(toastProvider: provider)

        let resolved: (any ToastProviding)? = kernel.resolveProvider((any ToastProviding).self)
        #expect(resolved as? CustomToastProvider === provider)
    }

    @Test("内核可解析出 ProjectProviding 并正常使用")
    func kernelResolvesUsableProvider() async throws {
        let kernel = try FactoryLumi2.makeKernel()

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

        #expect(project is DefaultProjectProviding)
        #expect(toast is DefaultToastProviding)
    }

    @Test("makeKernel(providers:) 使用自定义 ProviderFactory 注册")
    func makeKernelWithCustomFactory() throws {
        let custom = CustomProviderFactory()
        let kernel = try FactoryLumi2.makeKernel(providers: custom)

        let project: (any ProjectProviding)? = kernel.resolveProvider((any ProjectProviding).self)
        let toast: (any ToastProviding)? = kernel.resolveProvider((any ToastProviding).self)

        #expect(project is CustomProjectProvider)
        #expect(toast is CustomToastProvider)
    }

    /// 测试用自定义工厂：覆盖两种 Provider 的产出。
    private struct CustomProviderFactory: ProviderFactory {
        func makeProjectProvider() -> any ProjectProviding {
            CustomProjectProvider()
        }

        func makeToastProvider() -> any ToastProviding {
            CustomToastProvider()
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
}
