import Foundation
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

    @Test("input schema requires title and body and disallows extras")
    func inputSchemaContract() throws {
        let tool = CreateGitHubIssueTool()
        let schema = tool.inputSchema(for: .english)

        let properties = try #require(schema["properties"] as? [String: Any])
        for key in ["title", "body", "labels", "repository"] {
            #expect(properties[key] != nil, "missing property: \(key)")
        }

        let required = try #require(schema["required"] as? [String])
        #expect(required.contains("title"))
        #expect(required.contains("body"))

        let additional = schema["additionalProperties"] as? Bool
        #expect(additional == false)
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
        let path = GitHubCLI.locate()
        #expect(path != nil)
    }
}
