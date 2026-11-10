import Foundation
import KitAgentTool
import Testing
@testable import PluginGitHubIssue

/// 插件 + 工具的静态健全性检查。
///
/// 真正的 gh 调用路径依赖本地环境（gh 是否装、是否登录、网络），不适合在 CI
/// 做断言；这里只验证注册链路与 schema 契约稳定。
@Suite("PluginGitHubIssue")
@MainActor
struct PluginGitHubIssueTests {

    @Test("plugin has stable id and order")
    func pluginIdentity() {
        let plugin = GitHubIssuePlugin()
        #expect(plugin.id == "com.coffic.lumi.plugin.github-issue")
        #expect(plugin.order == 290)
        #expect(plugin.metadata.id == plugin.id)
        #expect(plugin.metadata.name == "GitHub Issue")
    }

    @Test("tool name is stable")
    func toolNameIsStable() {
        #expect(CreateGitHubIssueTool.toolName == "github_create_issue")
        #expect(CreateGitHubIssueTool().name == "github_create_issue")
    }

    @Test("default target repository is CofficLab/Lumi")
    func defaultRepositoryIsLumi() {
        #expect(CreateGitHubIssueTool.defaultRepository == "CofficLab/Lumi")
    }

    @Test("input schema requires title and body, disallows extras, no repository field")
    func inputSchemaContract() throws {
        let tool = CreateGitHubIssueTool()
        let schema = tool.inputSchema(for: .english)

        let properties = try #require(schema["properties"] as? [String: Any])
        // 只有 title / body / labels 三项；不再允许 LLM 指定 repository。
        for key in ["title", "body", "labels"] {
            #expect(properties[key] != nil, "missing property: \(key)")
        }
        #expect(properties["repository"] == nil, "repository field should be removed")

        let required = try #require(schema["required"] as? [String])
        #expect(required.contains("title"))
        #expect(required.contains("body"))

        let additional = schema["additionalProperties"] as? Bool
        #expect(additional == false)
    }

    @Test("description mentions Lumi's own repo")
    func descriptionMentionsLumiRepo() {
        let tool = CreateGitHubIssueTool()
        let desc = tool.description(for: .english)
        #expect(desc.contains("CofficLab/Lumi"))
        #expect(desc.contains("Lumi"))
    }

    @Test("input schema states English requirement")
    func schemaStatesEnglishRequirement() throws {
        let tool = CreateGitHubIssueTool()
        let schema = tool.inputSchema(for: .english)
        let properties = try #require(schema["properties"] as? [String: Any])

        let titleDesc = try #require((properties["title"] as? [String: Any])?["description"] as? String)
        #expect(titleDesc.lowercased().contains("english"))

        let bodyDesc = try #require((properties["body"] as? [String: Any])?["description"] as? String)
        #expect(bodyDesc.lowercased().contains("english"))
    }

    @Test("rendered body contains no non-Latin characters")
    func renderedBodyIsEnglish() {
        // 诊断表是工具自动追加的，随 issue 一起提交——必须全英文。
        let body = CreateGitHubIssueTool.renderedBodyForTesting(
            userBody: "The read_file tool returned an empty string for a non-empty file."
        )
        #expect(
            !EnglishLanguageGuard.containsNonEnglishContent(body),
            "rendered body must be pure English, got: \(body)"
        )
        #expect(body.contains("Environment"))
        #expect(body.contains("Lumi version"))
    }

    @Test("english violation is reported for Chinese title")
    func englishViolationDetectsChinese() {
        let offenders = CreateGitHubIssueTool.nonEnglishOffendersForTesting(
            title: "工具返回空结果",
            body: "This body is English."
        )
        #expect(!offenders.isEmpty)
        #expect(offenders.contains { $0.contains("title") })
    }

    @Test("english violation is empty for pure English content")
    func englishViolationPassesEnglish() {
        let offenders = CreateGitHubIssueTool.nonEnglishOffendersForTesting(
            title: "Tool returns empty result",
            body: "The read_file tool returned an empty string for a non-empty file."
        )
        #expect(offenders.isEmpty)
    }

    @Test("public issue creation always requires explicit approval (#1048)")
    func publicIssueRequiresExplicitApproval() {
        // 经存在类型调用，确保协议分派到工具自身的覆盖实现。
        let tool: any SuperAgentTool = CreateGitHubIssueTool()

        #expect(tool.requiresExplicitApproval(arguments: [:]))
        #expect(tool.requiresExplicitApproval(arguments: [
            "title": ToolArgument("Crash on launch"),
            "body": ToolArgument("Steps to reproduce: ..."),
        ]))
    }

    @Test("non-English content fails as a tool error instead of a successful result (#1051)")
    func nonEnglishContentThrowsToolError() async {
        // 经存在类型调用生产同款入口，确保走的是协议分派后的真实实现。
        let tool: any SuperAgentTool = CreateGitHubIssueTool()
        let context = ToolExecutionContext(jobID: "test-job", conversationID: UUID())

        do {
            _ = try await tool.executeResult(context: context, arguments: [
                "title": ToolArgument("工具失效"),
                "body": ToolArgument("This body is valid English and is only used to exercise validation."),
            ])
            Issue.record("Expected the language guard to fail the tool call")
        } catch let error as ToolExecutionError {
            #expect(error.errorDescription?.contains("Rejected") == true)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("missing title or body fails as a tool error instead of a successful result (#1051)")
    func missingArgumentsThrowToolError() async {
        let tool: any SuperAgentTool = CreateGitHubIssueTool()
        let context = ToolExecutionContext(jobID: "test-job", conversationID: UUID())

        do {
            _ = try await tool.executeResult(context: context, arguments: [:])
            Issue.record("Expected missing arguments to fail the tool call")
        } catch let error as ToolExecutionError {
            #expect(error.errorDescription?.contains("required") == true)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("description is non-empty")
    func descriptionNonEmpty() {
        let tool = CreateGitHubIssueTool()
        #expect(!tool.description(for: .english).isEmpty)
    }

    @Test("locate returns non-nil when gh is on PATH")
    func locateOnRealSystem() async {
        // 仅在有 gh 的 CI / 本机运行；缺 gh 时跳过而非失败。
        guard ProcessInfo.processInfo.environment["GITHUB_ISSUE_TEST_REQUIRE_GH"] == "1" else {
            return
        }
        let path = await GitHubCLI.locate()
        #expect(path != nil)
    }
}
