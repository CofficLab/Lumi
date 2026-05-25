import AgentToolKit
import LumiCoreKit
import ShellKit
import Testing
@testable import PluginGitHubCLIDetect

@Suite("PluginGitHubCLIDetect")
struct PluginGitHubCLIDetectTests {
    @Test("plugin metadata is stable")
    func pluginMetadata() {
        #expect(GitHubCLIDetectPlugin.id == "GitHubCLIDetect")
        #expect(GitHubCLIDetectPlugin.displayName == "GitHub CLI Detect")
        #expect(GitHubCLIDetectPlugin.iconName == "terminal")
        #expect(GitHubCLIDetectPlugin.category == .general)
        #expect(GitHubCLIDetectPlugin.order == 16)
    }

    @MainActor
    @Test("plugin registers one GitHub CLI check tool")
    func pluginRegistersTool() {
        let tools = GitHubCLIDetectPlugin.shared.agentTools(context: ToolContext())

        #expect(tools.count == 1)
        #expect(tools.first?.name == "github_cli_check")
    }

    @Test("tool schema has no required arguments")
    func toolSchemaHasNoRequiredArguments() {
        let tool = GitHubCLICheckTool()
        let schema = tool.inputSchema(for: .english)

        #expect(schema["type"] as? String == "object")
        #expect((schema["properties"] as? [String: Any])?.isEmpty == true)
        #expect(schema["required"] == nil)
    }

    @Test("tool risk level is low")
    func toolRiskLevel() {
        let tool = GitHubCLICheckTool()

        #expect(tool.permissionRiskLevel(arguments: [:]) == .low)
    }

    @Test("service reports installed CLI details")
    func serviceReportsInstalledDetails() {
        let service = GitHubCLIDetectService { command in
            switch command {
            case "which gh":
                return ShellResult(exitCode: 0, stdout: "/opt/homebrew/bin/gh", stderr: "")
            case "gh --version":
                return ShellResult(exitCode: 0, stdout: "gh version 2.65.0 (2025-01-01)\nextra", stderr: "")
            default:
                return ShellResult(exitCode: 127, stdout: "", stderr: "not found")
            }
        }

        let result = service.getDetectionDetails()

        #expect(result.installed == true)
        #expect(result.path == "/opt/homebrew/bin/gh")
        #expect(result.version == "gh version 2.65.0 (2025-01-01)")
        #expect(result.description.contains("已安装"))
    }

    @Test("service reports missing CLI")
    func serviceReportsMissingCLI() {
        let service = GitHubCLIDetectService { _ in
            ShellResult(exitCode: 1, stdout: "", stderr: "gh not found")
        }

        let result = service.getDetectionDetails()

        #expect(result.installed == false)
        #expect(result.path == nil)
        #expect(result.version == nil)
        #expect(result.description.contains("未安装"))
    }

    @Test("localization catalog is packaged")
    func localizationCatalogIsPackaged() {
        #expect(PluginGitHubCLIDetectLocalization.bundle.url(forResource: "GitHubCLIDetect", withExtension: "xcstrings") != nil)
        #expect(PluginGitHubCLIDetectLocalization.string("GitHub CLI Detect").isEmpty == false)
    }
}
