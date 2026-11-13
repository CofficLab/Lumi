import Foundation
import Testing

@testable import PluginAgentRules

/// 回归 #347：`createRule` 把 `filename` 直接拼到 `.lumi/rules` 后面，
/// `../../escaped` 之类的相对路径会越界写到项目根甚至更外层，绝对路径与
/// 经符号链接目录的逃逸同样不受限制。修复后这些输入必须抛 `pathTraversal`，
/// 而正常的 kebab-case 文件名仍落在规则根目录内。
@Suite("createRule 路径越界防护")
struct AgentRuleCreatePathTraversalTests {
    private func makeProjectURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentRulesTraversal-\(UUID().uuidString)", isDirectory: true)
    }

    @Test("父目录相对路径被拒绝且不越界落盘")
    func createRuleRejectsParentDirectoryTraversal() async throws {
        let projectURL = makeProjectURL()
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let service = AgentRulesService()
        await expectPathTraversal(service: service, projectPath: projectURL.path, filename: "../../escaped")

        // 旧实现会把文件写到项目根（.lumi/rules 上跳两级）；修复后不得越界落盘。
        let escaped = projectURL.appending(path: "escaped.md")
        #expect(!FileManager.default.fileExists(atPath: escaped.path))
    }

    @Test("绝对路径被拒绝")
    func createRuleRejectsAbsolutePath() async throws {
        let projectURL = makeProjectURL()
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let service = AgentRulesService()
        let absolute = projectURL.appending(path: "absolute.md").path
        await expectPathTraversal(service: service, projectPath: projectURL.path, filename: absolute)
    }

    @Test("文件名内部嵌入的 .. 成分被拒绝")
    func createRuleRejectsEmbeddedParentComponent() async throws {
        let projectURL = makeProjectURL()
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let service = AgentRulesService()
        await expectPathTraversal(service: service, projectPath: projectURL.path, filename: "sub/../../escaped")
    }

    @Test("经符号链接目录的逃逸被拒绝")
    func createRuleRejectsSymlinkEscape() async throws {
        let projectURL = makeProjectURL()
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let rulesURL = projectURL.appending(path: ".lumi/rules")
        try FileManager.default.createDirectory(at: rulesURL, withIntermediateDirectories: true)

        // 规则目录内放一个指向外层的符号链接，文件名经它越界。
        let outsideURL = projectURL.appending(path: "outside")
        try FileManager.default.createDirectory(at: outsideURL, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: rulesURL.appending(path: "escape"),
            withDestinationURL: outsideURL
        )

        let service = AgentRulesService()
        await expectPathTraversal(service: service, projectPath: projectURL.path, filename: "escape/pwned")
        #expect(!FileManager.default.fileExists(atPath: outsideURL.appending(path: "pwned.md").path))
    }

    @Test("正常 kebab-case 文件名仍创建在规则根目录内")
    func createRuleStillCreatesValidNameInsideRules() async throws {
        let projectURL = makeProjectURL()
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let service = AgentRulesService()
        let rule = try await service.createRule(
            projectPath: projectURL.path,
            filename: "my-rule",
            title: "My Rule",
            content: "Body."
        )

        #expect(rule.filePath == projectURL.appending(path: ".lumi/rules/my-rule.md").path)
        #expect(FileManager.default.fileExists(atPath: rule.filePath))
    }

    // MARK: - Helpers

    /// 断言 `createRule` 对越界文件名抛出 `AgentRulesError.pathTraversal`。
    private func expectPathTraversal(
        service: AgentRulesService,
        projectPath: String,
        filename: String
    ) async {
        do {
            _ = try await service.createRule(
                projectPath: projectPath,
                filename: filename,
                title: "T",
                content: "body"
            )
            Issue.record("createRule should reject traversal filename: \(filename)")
        } catch let error as AgentRulesError {
            guard case .pathTraversal = error else {
                Issue.record("expected pathTraversal for \(filename), got \(error)")
                return
            }
        } catch {
            Issue.record("expected AgentRulesError.pathTraversal for \(filename), got \(error)")
        }
    }
}