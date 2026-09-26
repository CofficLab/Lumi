import Foundation
import KernelCore
import KitMCP
import KitSuperLog
import os
import ProviderMCP

/// Contributes Google's Chrome DevTools MCP server to Lumi's MCP registry.
///
/// PluginMCP owns the connection and tool lifecycle. This plugin only provides
/// the server configuration, keeping browser automation in the upstream server.
@MainActor
public final class PluginChromeMCP: SuperPlugin, SuperLog {
    nonisolated public static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.chrome-mcp",
        category: "ChromeMCP"
    )

    public let id = "com.coffic.lumi.plugin.chrome-mcp"
    public let order = 282
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.chrome-mcp",
        name: "Chrome DevTools MCP",
        description: "Contributes Google's Chrome DevTools MCP server for browser automation and inspection.",
        category: .integration,
        stage: .preview,
        policy: .required
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any MCPServerContributionProviding).self)?.contribute(
            MCPServerConfig(
                name: "Chrome DevTools (official)",
                command: "npx",
                arguments: ["-y", "chrome-devtools-mcp@latest"]
            )
        )
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {}
}
