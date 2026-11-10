import Foundation
import ProviderProject
import Testing
@testable import PluginAgentRules

/// Agent Rules 设置页持有 ViewModel 的项目增删行为。
///
/// 设置页在插件启用期间长期存在，`AgentRulesProjectObserver` 会把项目目录变化
/// 直接写入该 ViewModel。项目被移除（尤其是最后一个项目）后，页面必须同步清空
/// 旧项目留下的规则与错误，而不是继续展示已移除项目的计数（#899）。
@Suite("AgentRulesViewModel")
@MainActor
struct AgentRulesViewModelTests {
    @Test("移除最后一个项目后清空已加载规则与选中路径（回归 #899）")
    func removingLastProjectClearsLoadedRules() async throws {
        let project = try makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: project) }
        try writeRule(at: project, filename: "one.md", content: "# One\n\nFirst rule.")

        let viewModel = AgentRulesViewModel()

        viewModel.updateProjects([ProjectInfo(name: "Demo", path: project.path())])
        try await waitUntil { viewModel.rules.count == 1 }
        #expect(viewModel.selectedProjectPath == project.path())

        viewModel.updateProjects([])

        #expect(viewModel.selectedProjectPath == nil)
        #expect(viewModel.rules.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("移除最后一个项目后清空加载错误（回归 #899）")
    func removingLastProjectClearsErrorMessage() async throws {
        let project = try makeProjectDirectory()
        let rulesDirectory = project.appending(path: ".lumi/rules", directoryHint: .isDirectory)
        // 目录不可读，让真实服务在列出规则时抛错，从而写入 errorMessage。
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o000],
            ofItemAtPath: rulesDirectory.path()
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: rulesDirectory.path()
            )
            try? FileManager.default.removeItem(at: project)
        }

        let viewModel = AgentRulesViewModel()

        viewModel.updateProjects([ProjectInfo(name: "Demo", path: project.path())])
        try await waitUntil { viewModel.errorMessage != nil }
        #expect(viewModel.rules.isEmpty)

        viewModel.updateProjects([])

        #expect(viewModel.selectedProjectPath == nil)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.rules.isEmpty)
    }

    private func makeProjectDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentRulesViewModel-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: root.appending(path: ".lumi/rules", directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
        return root
    }

    private func writeRule(at project: URL, filename: String, content: String) throws {
        let fileURL = project.appending(path: ".lumi/rules/\(filename)")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private func waitUntil(
        timeout: Duration = .seconds(2),
        _ condition: () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !condition() {
            if ContinuousClock.now > deadline {
                Issue.record("等待条件超时")
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
    }
}
