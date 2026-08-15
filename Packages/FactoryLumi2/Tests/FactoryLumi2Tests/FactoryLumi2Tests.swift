import Foundation
import KernelCore
import ProviderProject
import Testing
@testable import FactoryLumi2

@MainActor
@Suite("FactoryLumi2")
struct FactoryLumi2Tests {

    @Test("makeKernel 创建内核并注册默认 ProjectProviding")
    func makeKernelRegistersDefaultProjectProviding() throws {
        let kernel = try FactoryLumi2.makeKernel()

        let resolved: (any ProjectProviding)? = kernel.resolveProvider(ProjectProviding.self)
        #expect(resolved != nil)
        #expect(resolved is DefaultProjectProviding)
    }

    @Test("makeKernel 支持注入自定义 ProjectProviding 实现")
    func makeKernelAcceptsCustomProvider() throws {
        let provider = CustomProjectProvider()
        let kernel = try FactoryLumi2.makeKernel(projectProvider: provider)

        let resolved: (any ProjectProviding)? = kernel.resolveProvider(ProjectProviding.self)
        #expect(resolved as? CustomProjectProvider === provider)
    }

    @Test("内核可解析出 ProjectProviding 并正常使用")
    func kernelResolvesUsableProvider() async throws {
        let kernel = try FactoryLumi2.makeKernel()

        let project: (any ProjectProviding)? = kernel.resolveProvider(ProjectProviding.self)
        try await project?.openProject(at: "/Users/me/Code/Lumi")

        #expect(project?.currentProject?.name == "Lumi")
        #expect(project?.currentProject?.path == "/Users/me/Code/Lumi")
    }

    /// 测试用自定义实现。
    private final class CustomProjectProvider: ProjectProviding {
        var currentProject: ProjectInfo?
        var projects: [ProjectInfo] = []

        func openProject(at path: String) async throws {
            currentProject = ProjectInfo(name: "custom", path: path)
        }

        func closeProject() async {}

        func refreshProjects() async throws {}
    }
}
