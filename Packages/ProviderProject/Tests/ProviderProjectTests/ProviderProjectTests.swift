import Combine
import Foundation
import Testing
@testable import ProviderProject

/// ProjectProviding 协议与 ProjectInfo 模型的基础验证。
@Suite("ProviderProject")
@MainActor
struct ProviderProjectTests {

    /// 测试用实现：验证协议可被任意实现注入。
    private final class MockProjectProvider: ProjectProviding {
        @Published var currentProject: ProjectInfo?
        @Published var projects: [ProjectInfo] = []

        var openFileURLs: [URL] = []
        var currentFileURL: URL?

        func openProject(at path: String) async throws {
            currentProject = ProjectInfo(name: (path as NSString).lastPathComponent, path: path)
        }

        func closeProject() async {
            currentProject = nil
        }

        func refreshProjects() async throws {}
    }

    @Test("ProjectInfo 可创建且 Codable 往返")
    func projectInfoCodableRoundTrip() throws {
        let info = ProjectInfo(name: "Lumi", path: "/Users/me/Code/Lumi", language: "swift")

        let data = try JSONEncoder().encode(info)
        let decoded = try JSONDecoder().decode(ProjectInfo.self, from: data)

        #expect(decoded.name == "Lumi")
        #expect(decoded.path == "/Users/me/Code/Lumi")
        #expect(decoded.language == "swift")
    }

    @Test("ProjectProviding 可注册实现并通过协议访问")
    func providerAccessibleThroughProtocol() async throws {
        let provider = MockProjectProvider()
        try await provider.openProject(at: "/Users/me/Code/Lumi")

        let resolved: any ProjectProviding = provider
        #expect(resolved.currentProject?.name == "Lumi")

        await provider.closeProject()
        #expect(resolved.currentProject == nil)
    }

    @Test("默认实现为空操作，无需实现类覆盖")
    func defaultImplementationsAreNoOps() {
        let provider = MockProjectProvider()

        // 这些默认实现不应抛错或产生副作用
        provider.updateCurrentFile(nil)
        provider.updateOpenFiles([])
        provider.closeFile(URL(fileURLWithPath: "/tmp/x.swift"))
        provider.synchronizeProjects([])

        #expect(provider.currentFileURL == nil)
        #expect(provider.openFileURLs.isEmpty)
    }

    // MARK: - DefaultProjectProviding

    @Test("DefaultProjectProviding 打开/关闭项目并维护列表")
    func defaultProviderOpenClose() async throws {
        let provider = DefaultProjectProviding()

        try await provider.openProject(at: "/Users/me/Code/Lumi")
        #expect(provider.currentProject?.name == "Lumi")
        #expect(provider.projects.count == 1)

        // 重复打开同一项目不会重复添加
        try await provider.openProject(at: "/Users/me/Code/Lumi")
        #expect(provider.projects.count == 1)

        await provider.closeProject()
        #expect(provider.currentProject == nil)
    }

    @Test("DefaultProjectProviding 可作为 any ProjectProviding 使用")
    func defaultProviderAsExistential() async throws {
        let provider: any ProjectProviding = DefaultProjectProviding()
        try await provider.openProject(at: "/tmp/Demo")
        #expect(provider.currentProject?.name == "Demo")
    }
}
