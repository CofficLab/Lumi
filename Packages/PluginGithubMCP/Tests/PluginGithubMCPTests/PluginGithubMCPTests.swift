import Foundation
import Testing
@testable import PluginGithubMCP
import ProviderMCP
import KitMCP

// MARK: - Mock

@MainActor
private final class RecordingContributionProvider: MCPServerContributionProviding {
    private(set) var contributed: [MCPServerConfig] = []

    func contribute(_ server: MCPServerConfig) {
        contributed.append(server)
    }
}

@Suite("PluginGithubMCP Tests")
@MainActor
struct PluginGithubMCPTests {

    @Test("插件身份与元数据稳定")
    func pluginIdentityAndMetadata() {
        let plugin = PluginGithubMCP()

        #expect(plugin.id == "com.coffic.lumi.plugin.github-mcp")
        #expect(plugin.order == 281)

        #expect(plugin.metadata.id == "com.coffic.lumi.plugin.github-mcp")
        #expect(plugin.metadata.name == "GitHub MCP")
        #expect(plugin.metadata.description.contains("GitHub"))
        #expect(plugin.metadata.category.rawValue == "integration")
        #expect(plugin.metadata.stage.rawValue == "preview")
        #expect(plugin.metadata.policy.rawValue == "required")
    }

    @Test("init 不崩溃且 logger 子系统正确")
    func initDoesNotCrash() {
        let plugin = PluginGithubMCP()
        #expect(plugin.id == "com.coffic.lumi.plugin.github-mcp")
        // logger is nonisolated static, verify subsystem
        #expect(PluginGithubMCP.logger.subsystem == "com.coffic.lumi.plugin.github-mcp")
        #expect(PluginGithubMCP.logger.category == "GithubMCP")
    }

    @Test("onShutdown 不抛错")
    func onShutdownDoesNotThrow() async throws {
        let plugin = PluginGithubMCP()
        let kernel = KernelCoreContainer()
        try plugin.onShutdown(kernel: kernel)
    }

    @Test("onBoot 在无贡献收集器时不崩溃")
    func onBootWithoutContributionProviderDoesNotCrash() async throws {
        let plugin = PluginGithubMCP()
        let kernel = KernelCoreContainer()
        // resolveProvider 返回 nil 时，onBoot 应安全跳过
        try plugin.onBoot(kernel: kernel)
    }

    @Test("onBoot 贡献 GitHub MCP 服务器模板")
    func onBootContributesGithubTemplate() async throws {
        let kernel = KernelCoreContainer()
        let recorder = RecordingContributionProvider()
        try kernel.registerProvider((any MCPServerContributionProviding).self, recorder)

        let plugin = PluginGithubMCP()
        try plugin.onBoot(kernel: kernel)

        #expect(recorder.contributed.count == 1)
        let server = recorder.contributed[0]
        #expect(server.name == "GitHub")
        #expect(server.command == "docker")
        #expect(server.arguments.contains("ghcr.io/github/github-mcp-server"))
        #expect(server.arguments.contains("run"))
    }
}
