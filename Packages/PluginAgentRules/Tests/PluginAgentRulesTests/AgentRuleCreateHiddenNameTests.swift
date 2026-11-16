import Foundation
import ProviderAgentRules
import Testing

@testable import PluginAgentRules

/// 回归 #810：`createRule` 接受以 `.` 开头的隐藏文件名并报告成功，但 `listRules`
/// 与 `loadRuleDefinitions` 都用 `.skipsHiddenFiles`，落盘的 `.hidden.md` 永远不会
/// 被列出或注入。用户/模型以为项目约束已生效，Agent 实际不带这些约束执行。
/// 修复后创建入口必须拒绝隐藏名，且正常文件名创建后仍能在两条读取链中出现。
@Suite("createRule 隐藏文件名防护（#810）")
struct AgentRuleCreateHiddenNameTests {
    private func makeProjectURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentRulesHidden-\(UUID().uuidString)", isDirectory: true)
    }

    @Test("以 . 开头的文件名被拒绝且不落盘")
    func createRuleRejectsHiddenFilename() async throws {
        let projectURL = makeProjectURL()
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let service = AgentRulesService()
        await expectInvalidFilename(service: service, projectPath: projectURL.path, filename: ".hidden")

        // 旧实现会写出 .lumi/rules/.hidden.md 并报告成功；修复后不得落盘。
        let hidden = projectURL.appending(path: ".lumi/rules/.hidden.md")
        #expect(!FileManager.default.fileExists(atPath: hidden.path))
    }

    @Test("自带 .md 扩展名的隐藏文件名同样被拒绝")
    func createRuleRejectsHiddenFilenameWithExtension() async throws {
        let projectURL = makeProjectURL()
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let service = AgentRulesService()
        await expectInvalidFilename(service: service, projectPath: projectURL.path, filename: ".hidden.md")

        let hidden = projectURL.appending(path: ".lumi/rules/.hidden.md")
        #expect(!FileManager.default.fileExists(atPath: hidden.path))
    }

    @Test("隐藏目录成分下的文件名被拒绝（.skipsHiddenFiles 逐层跳过）")
    func createRuleRejectsHiddenDirectoryComponent() async throws {
        let projectURL = makeProjectURL()
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let service = AgentRulesService()
        await expectInvalidFilename(service: service, projectPath: projectURL.path, filename: ".config/rule")

        let hidden = projectURL.appending(path: ".lumi/rules/.config/rule.md")
        #expect(!FileManager.default.fileExists(atPath: hidden.path))
    }

    @Test("正常文件名创建后必须同时出现在列表与注入两条读取链中")
    func createdVisibleRuleIsListedAndInjected() async throws {
        let projectURL = makeProjectURL()
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let service = AgentRulesService()
        let rule = try await service.createRule(
            projectPath: projectURL.path,
            filename: "my-rule",
            title: "My Rule",
            content: "Body."
        )

        // 创建报告成功 ⇒ 规则必须可被列出且可被注入，否则就是 #810 的静默忽略。
        let listed = try await service.listRules(projectPath: projectURL.path)
        #expect(listed.contains { $0.filename == rule.filename })

        let definitions = await service.loadRuleDefinitions(projectPath: projectURL.path)
        #expect(definitions.contains { $0.id == rule.id })
    }

    @Test("两条读取链都跳过磁盘上的隐藏规则文件（拒绝创建的根因）")
    func readChainsSkipHiddenFileOnDisk() async throws {
        let projectURL = makeProjectURL()
        defer { try? FileManager.default.removeItem(at: projectURL) }

        // 绕过创建入口直接写一个隐藏规则，复现旧版本落盘后的磁盘状态。
        let rulesURL = projectURL.appending(path: ".lumi/rules")
        try FileManager.default.createDirectory(at: rulesURL, withIntermediateDirectories: true)
        try "# Hidden\n\nmust apply\n".write(
            to: rulesURL.appending(path: ".hidden.md"),
            atomically: true,
            encoding: .utf8
        )

        let service = AgentRulesService()
        let listed = try await service.listRules(projectPath: projectURL.path)
        #expect(!listed.contains { $0.filename == ".hidden.md" })

        let definitions = await service.loadRuleDefinitions(projectPath: projectURL.path)
        #expect(!definitions.contains { $0.id == ".hidden" })
    }

    // MARK: - Helpers

    /// 断言 `createRule` 对隐藏文件名抛出 `AgentRulesError.invalidFileFormat`。
    private func expectInvalidFilename(
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
            Issue.record("createRule should reject hidden filename: \(filename)")
        } catch let error as AgentRulesError {
            guard case .invalidFileFormat = error else {
                Issue.record("expected invalidFileFormat for \(filename), got \(error)")
                return
            }
        } catch {
            Issue.record("expected AgentRulesError.invalidFileFormat for \(filename), got \(error)")
        }
    }
}