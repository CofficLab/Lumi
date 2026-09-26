import Foundation
import Testing
@testable import PluginXcodeMCP
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

@Suite("PluginXcodeMCP Tests")
@MainActor
struct PluginXcodeMCPTests {

    @Test("插件身份与元数据稳定")
    func pluginIdentityAndMetadata() {
        let plugin = PluginXcodeMCP()

        #expect(plugin.id == "com.coffic.lumi.plugin.xcode-mcp")
        #expect(plugin.order == 280)

        #expect(plugin.metadata.id == "com.coffic.lumi.plugin.xcode-mcp")
        #expect(plugin.metadata.name == "Xcode MCP")
        #expect(plugin.metadata.description.contains("Xcode"))
        #expect(plugin.metadata.category.rawValue == "integration")
        #expect(plugin.metadata.stage.rawValue == "preview")
        #expect(plugin.metadata.policy.rawValue == "required")
    }

    @Test("init 不崩溃且 logger 子系统正确")
    func initDoesNotCrash() {
        let plugin = PluginXcodeMCP()
        #expect(plugin.id == "com.coffic.lumi.plugin.xcode-mcp")
        #expect(PluginXcodeMCP.logger.subsystem == "com.coffic.lumi.plugin.xcode-mcp")
        #expect(PluginXcodeMCP.logger.category == "XcodeMCP")
    }

    @Test("onShutdown 不抛错")
    func onShutdownDoesNotThrow() async throws {
        let plugin = PluginXcodeMCP()
        let kernel = KernelCoreContainer()
        try plugin.onShutdown(kernel: kernel)
    }

    @Test("onBoot 在无贡献收集器时不崩溃")
    func onBootWithoutContributionProviderDoesNotCrash() async throws {
        let plugin = PluginXcodeMCP()
        let kernel = KernelCoreContainer()
        try plugin.onBoot(kernel: kernel)
    }

    @Test("onBoot 贡献 Xcode 原生 MCP 服务器配置")
    func onBootContributesXcodeConfig() async throws {
        let kernel = KernelCoreContainer()
        let recorder = RecordingContributionProvider()
        try kernel.registerProvider((any MCPServerContributionProviding).self, recorder)

        let plugin = PluginXcodeMCP()
        try plugin.onBoot(kernel: kernel)

        #expect(recorder.contributed.count == 1)
        let server = recorder.contributed[0]
        #expect(server.name == "Xcode (native)")
        #expect(server.command == "xcrun")
        #expect(server.arguments == ["mcpbridge"])
    }
}
