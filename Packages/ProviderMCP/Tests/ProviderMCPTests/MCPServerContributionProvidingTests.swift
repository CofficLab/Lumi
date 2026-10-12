import Testing
import Foundation
@testable import ProviderMCP
import KitMCP

// MARK: - Mock

/// 记录收到的贡献，用于验证 `MCPServerContributionProviding.contribute(_:)` 被调用时
/// 能透传正确的 `MCPServerConfig`。
@MainActor
private final class RecordingContributionProvider: MCPServerContributionProviding {
    private(set) var contributed: [MCPServerConfig] = []

    func contribute(_ server: MCPServerConfig) {
        contributed.append(server)
    }
}

@Suite("MCPServerContributionProviding Tests")
@MainActor
struct MCPServerContributionProvidingTests {

    @Test("协议可被类类型遵循，并接收 contribute 调用")
    func conformsAndReceivesContribution() {
        let provider = RecordingContributionProvider()
        let server = MCPServerConfig(
            name: "Test Server",
            command: "node",
            arguments: ["server.js"]
        )

        provider.contribute(server)

        #expect(provider.contributed.count == 1)
        #expect(provider.contributed[0].name == "Test Server")
        #expect(provider.contributed[0].command == "node")
        #expect(provider.contributed[0].arguments == ["server.js"])
    }

    @Test("多次贡献按调用顺序累积")
    func accumulatesContributionsInOrder() {
        let provider = RecordingContributionProvider()
        let first = MCPServerConfig(name: "First", command: "a")
        let second = MCPServerConfig(name: "Second", command: "b", arguments: ["x"])

        provider.contribute(first)
        provider.contribute(second)

        #expect(provider.contributed.map(\.name) == ["First", "Second"])
        #expect(provider.contributed[1].arguments == ["x"])
    }

    @Test("contribute 透传完整字段（环境变量 / 传输方式 / 启用态）")
    func passesThroughFullConfiguration() {
        let provider = RecordingContributionProvider()
        let server = MCPServerConfig(
            name: "HTTP Server",
            command: "uvx",
            arguments: ["mcp-proxy"],
            environment: ["TOKEN": "secret"],
            transport: .streamableHTTP,
            url: "https://example.com/mcp",
            autoStart: true,
            enabled: false
        )

        provider.contribute(server)

        #expect(provider.contributed.count == 1)
        let received = provider.contributed[0]
        #expect(received.environment["TOKEN"] == "secret")
        #expect(received.transport == .streamableHTTP)
        #expect(received.url == "https://example.com/mcp")
        #expect(received.autoStart == true)
        #expect(received.enabled == false)
    }

    @Test("协议为 class-bound（AnyObject），可做身份比较")
    func isClassBound() {
        let providerA = RecordingContributionProvider()
        let providerB: any MCPServerContributionProviding = RecordingContributionProvider()

        let same: any MCPServerContributionProviding = providerA
        // AnyObject 约束使 === 可用。
        #expect(providerA === same)
        #expect((providerA as AnyObject) !== (providerB as AnyObject))
    }
}
