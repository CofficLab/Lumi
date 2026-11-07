import Foundation
import KitOpenIn
import ProviderProject
import Testing
@testable import PluginOpenInCursor

@Suite("OpenInCursor Toolbar")
@MainActor
struct OpenInCursorToolbarViewModelTests {
    /// 回归 #549：打开失败必须走用户可见的失败反馈，而不是只写日志。
    @Test("打开失败时把错误交给失败反馈")
    func failureIsReportedToUser() async throws {
        let projectPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiOpenIn-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: projectPath, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectPath) }

        let config = OpenInTool.AppConfig(
            toolName: "open_in_missing",
            displayName: "Missing App",
            systemImage: "questionmark",
            bundleIdentifier: nil,
            fallbackPath: "/nonexistent/LumiMissingApp.app"
        )
        let tool = OpenInTool(config: config, project: StubProjectProvider(path: projectPath.path))
        let capability = StubProjectCapability(currentProjectPath: projectPath.path)
        let reporter = SpyFailureReporter()
        let model = OpenInCursorToolbarViewModel(
            tool: tool,
            projectCapability: capability,
            failureReporter: reporter
        )

        model.openProjectInCursor()

        for _ in 0..<100 {
            if !reporter.failures.isEmpty { break }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        #expect(model.isOpening == false)
        #expect(reporter.failures.count == 1)
        #expect(reporter.failures.first?.title.isEmpty == false)
        #expect(reporter.failures.first?.detail?.isEmpty == false)
    }
}

@MainActor
private final class SpyFailureReporter: OpenInFailureReporting {
    private(set) var failures: [(title: String, detail: String?)] = []

    func reportOpenFailure(title: String, detail: String?) {
        failures.append((title, detail))
    }
}

@MainActor
private final class StubProjectCapability: OpenInProjectCapability {
    let currentProjectPath: String?

    init(currentProjectPath: String?) {
        self.currentProjectPath = currentProjectPath
    }

    func addProjectObserver(
        _ callback: @escaping (OpenInProjectEvent) -> Void
    ) -> any OpenInProjectObserverHandle {
        StubProjectObserverHandle()
    }
}

@MainActor
private final class StubProjectObserverHandle: OpenInProjectObserverHandle {
    func cancel() {}
}

/// 最小项目能力：只提供当前项目路径，其余成员保持空实现。
@MainActor
private final class StubProjectProvider: ProjectProviding {
    let currentProject: ProjectInfo?

    init(path: String) {
        currentProject = ProjectInfo(name: "LumiOpenIn", path: path)
    }

    var openFileURLs: [URL] { [] }
    var currentFileURL: URL? { nil }
    var projects: [ProjectInfo] { currentProject.map { [$0] } ?? [] }

    func openProject(at path: String, reason: ProjectChangeReason) async throws {}
    func updateCurrentFile(_ fileURL: URL?) {}
    func previewFile(_ fileURL: URL) {}
    func pinFile(_ fileURL: URL) {}
    func activateFile(_ fileURL: URL) {}
    func updateOpenFiles(_ fileURLs: [URL]) {}
    func closeFile(_ fileURL: URL) {}
    func closeProject(reason: ProjectChangeReason) async {}
    func refreshProjects() async throws {}
    func synchronizeProjects(_ projects: [ProjectInfo]) {}

    @discardableResult
    func addObserver(
        _ callback: @escaping (ProjectProvidingEvent) -> Void
    ) -> any ProjectProvidingObserverHandle {
        StubProjectProviderObserverHandle()
    }
}

@MainActor
private final class StubProjectProviderObserverHandle: ProjectProvidingObserverHandle {
    func cancel() {}
}
