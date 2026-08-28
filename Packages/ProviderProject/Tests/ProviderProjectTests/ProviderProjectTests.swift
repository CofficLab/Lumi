import Foundation
import Testing
@testable import ProviderProject

/// ProjectProviding 协议与 ProjectInfo 模型的基础验证。
@Suite("ProviderProject")
@MainActor
struct ProviderProjectTests {

    /// 测试用实现：验证协议可被任意实现注入。
    private final class MockProjectProvider: ProjectProviding {
        var currentProject: ProjectInfo?
        var projects: [ProjectInfo] = []

        var openFileURLs: [URL] = []
        var currentFileURL: URL?

        func openProject(at path: String) async throws {
            currentProject = ProjectInfo(name: (path as NSString).lastPathComponent, path: path)
        }

        func closeProject() async {
            currentProject = nil
        }

        func refreshProjects() async throws {}

        func updateCurrentFile(_ fileURL: URL?) { currentFileURL = fileURL }
        func updateOpenFiles(_ fileURLs: [URL]) { openFileURLs = fileURLs }
        func closeFile(_ fileURL: URL) { openFileURLs.removeAll { $0 == fileURL } }
        func synchronizeProjects(_ projects: [ProjectInfo]) {}
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

    @Test("Mock 实现可操作文件状态")
    func mockProjectProviderFileState() {
        let provider = MockProjectProvider()

        let fileURL = URL(fileURLWithPath: "/tmp/x.swift")
        provider.updateCurrentFile(fileURL)
        #expect(provider.currentFileURL == fileURL)

        provider.updateOpenFiles([fileURL])
        #expect(provider.openFileURLs == [fileURL])

        provider.closeFile(fileURL)
        #expect(provider.openFileURLs.isEmpty)
    }

    // MARK: - DefaultProjectProvider

    @Test("DefaultProjectProvider 打开/关闭项目并维护列表")
    func defaultProviderOpenClose() async throws {
        let provider = DefaultProjectProvider()

        try await provider.openProject(at: "/Users/me/Code/Lumi")
        #expect(provider.currentProject?.name == "Lumi")
        #expect(provider.projects.count == 1)

        // 重复打开同一项目不会重复添加
        try await provider.openProject(at: "/Users/me/Code/Lumi")
        #expect(provider.projects.count == 1)

        await provider.closeProject()
        #expect(provider.currentProject == nil)
    }

    @Test("DefaultProjectProvider 可作为 any ProjectProviding 使用")
    func defaultProviderAsExistential() async throws {
        let provider: any ProjectProviding = DefaultProjectProvider()
        try await provider.openProject(at: "/tmp/Demo")
        #expect(provider.currentProject?.name == "Demo")
    }

    @Test("DefaultProjectProvider 支持预览、固定、激活与邻接文件切换")
    func defaultProviderFileOpeningSemantics() {
        let provider = DefaultProjectProvider()
        let first = URL(fileURLWithPath: "/tmp/first.swift")
        let second = URL(fileURLWithPath: "/tmp/second.swift")
        let preview = URL(fileURLWithPath: "/tmp/preview.swift")

        provider.updateOpenFiles([first, second])
        provider.previewFile(preview)
        #expect(provider.openFileURLs == [first, second])
        #expect(provider.currentFileURL == preview)

        provider.pinFile(preview)
        #expect(provider.openFileURLs == [first, second, preview])
        #expect(provider.currentFileURL == preview)

        provider.activateFile(first)
        provider.closeFile(first)
        #expect(provider.openFileURLs == [second, preview])
        #expect(provider.currentFileURL == second)

        provider.previewFile(URL(fileURLWithPath: "/tmp/unpinned.swift"))
        provider.closeFile(URL(fileURLWithPath: "/tmp/unpinned.swift"))
        #expect(provider.currentFileURL == preview)
    }

    @Test("DefaultProjectProvider 发出项目与文件状态事件")
    func defaultProviderEmitsSemanticEvents() async throws {
        let provider = DefaultProjectProvider()
        let projectPath = "/Users/me/Code/Lumi"
        let fileURL = URL(fileURLWithPath: projectPath).appendingPathComponent("Sources/App.swift")
        var events: [ProjectProvidingEvent] = []

        let handle = provider.addObserver { event in
            events.append(event)
        }

        try await provider.openProject(at: projectPath)
        provider.updateOpenFiles([fileURL])
        provider.updateCurrentFile(fileURL)
        provider.closeFile(fileURL)
        await provider.closeProject()

        #expect(events.count == 7)
        if case .projectsChanged(let projects) = events[0] {
            #expect(projects == provider.projects)
        } else {
            Issue.record("Expected a projectsChanged event after opening a new project")
        }
        if case .currentProjectChanged(let project) = events[1] {
            #expect(project?.path == projectPath)
        } else {
            Issue.record("Expected a currentProjectChanged event after opening a project")
        }
        if case .openFilesChanged(let files) = events[2] {
            #expect(files == [fileURL])
        } else {
            Issue.record("Expected an openFilesChanged event")
        }
        if case .currentFileChanged(let currentFile) = events[3] {
            #expect(currentFile == fileURL)
        } else {
            Issue.record("Expected a currentFileChanged event")
        }
        if case .openFilesChanged(let files) = events[4] {
            #expect(files.isEmpty)
        } else {
            Issue.record("Expected an openFilesChanged event after closing a file")
        }
        if case .currentFileChanged(let currentFile) = events[5] {
            #expect(currentFile == nil)
        } else {
            Issue.record("Expected currentFileChanged(nil) after closing the current file")
        }
        if case .currentProjectChanged(let project) = events[6] {
            #expect(project == nil)
        } else {
            Issue.record("Expected currentProjectChanged(nil) after closing the project")
        }

        handle.cancel()
        provider.updateCurrentFile(fileURL)
        #expect(events.count == 7)
    }
}
