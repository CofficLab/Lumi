import Foundation
import KitAgentTool
import ProviderProject
import Testing
@testable import PluginProjects

/// `list_projects` 的 limit 边界回归：非法值必须在 `prefix(_:)` 之前被拒绝。
@MainActor
@Suite("ListProjectsTool", .serialized)
struct ListProjectsToolTests {
    private func installRuntime() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ListProjectsToolTests-\(UUID().uuidString)")
        let store = ProjectsStore(pluginDirectory: directory)
        let provider = DefaultProjectProvider()
        provider.synchronizeProjects([
            ProjectInfo(name: "Demo", path: "/tmp/demo"),
            ProjectInfo(name: "Other", path: "/tmp/other"),
        ])
        let viewModel = ProjectsViewModel(
            store: store,
            projectCapability: ProjectsProjectCapabilityAdapter(project: provider)
        )
        let observer = ProjectProvidingObserver(project: provider, viewModel: viewModel)
        ProjectsRuntime.configure(viewModel: viewModel, projectObserver: observer)
        return directory
    }

    private func removeRuntime(_ directory: URL) {
        ProjectsRuntime.reset()
        try? FileManager.default.removeItem(at: directory)
    }

    @Test("negative limit throws instead of trapping in prefix")
    func negativeLimitReturnsParameterError() async throws {
        let directory = installRuntime()
        defer { removeRuntime(directory) }

        await #expect(throws: ToolExecutionError.self) {
            _ = try await ListProjectsTool().executeResult(arguments: ["limit": ToolArgument(-1)])
        }
    }

    @Test("zero limit throws instead of returning nothing")
    func zeroLimitReturnsParameterError() async throws {
        let directory = installRuntime()
        defer { removeRuntime(directory) }

        await #expect(throws: ToolExecutionError.self) {
            _ = try await ListProjectsTool().executeResult(arguments: ["limit": ToolArgument(0)])
        }
    }

    @Test("non-integer limit throws instead of falling back silently")
    func nonIntegerLimitReturnsParameterError() async throws {
        let directory = installRuntime()
        defer { removeRuntime(directory) }

        await #expect(throws: ToolExecutionError.self) {
            _ = try await ListProjectsTool().executeResult(arguments: ["limit": ToolArgument(1e100)])
        }
    }

    @Test("limit defaults to five and caps at five hundred")
    func limitDefaultsAndCaps() {
        #expect(ListProjectsTool.resolvedLimit(arguments: [:]) == 5)
        #expect(ListProjectsTool.resolvedLimit(arguments: ["limit": ToolArgument(3)]) == 3)
        #expect(ListProjectsTool.resolvedLimit(arguments: ["limit": ToolArgument(900)]) == 500)
    }
}
