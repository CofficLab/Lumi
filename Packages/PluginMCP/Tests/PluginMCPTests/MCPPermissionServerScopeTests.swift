import Foundation
import KitAgentTool
import KitMCP
import Testing
@testable import PluginMCP

/// Issue #530：Xcode 精确规则表必须只作用于 Xcode 原生 mcpbridge 服务器。
///
/// ## 为什么要有这些测试
///
/// 旧实现按裸工具名匹配精确表，且命中发生在 `destructiveHint` 之前。任何
/// 非 Xcode 服务器只要暴露一个同名工具（如 `XcodeRead`）并声明
/// `destructiveHint: true`，就会继承 Xcode 的 `.safe` 分级，从而在 Build
/// 自动化级别被自动批准执行破坏性操作，绕过确认。
///
/// 正确行为：精确表只在确认会话来自 Xcode 原生桥时套用；foreign 服务器的
/// 同名破坏性工具必须回落到 `destructiveHint` → `high`，要求确认。
@Suite("MCP 精确规则的服务器身份边界（#530）")
struct MCPPermissionServerScopeTests {
    private func tool(
        _ name: String,
        readOnly: Bool? = nil,
        destructive: Bool? = nil
    ) -> MCPToolDescriptor {
        MCPToolDescriptor(
            name: name,
            description: "test",
            inputSchemaJSON: "{}",
            readOnlyHint: readOnly,
            destructiveHint: destructive
        )
    }

    // MARK: - 策略层：跨服务器同名工具不得继承 Xcode 分级

    @Test("foreign 服务器的同名破坏性工具按 destructiveHint 判 high，不继承精确表")
    func foreignDestructiveSameNameIsHigh() {
        let policy = MCPPermissionPolicy()
        // 这些名字在 Xcode 精确表里分别是 safe / low / medium；
        // foreign 服务器声明 destructiveHint 后必须一律 high。
        #expect(policy.level(for: tool("XcodeRead", destructive: true)) == .high)
        #expect(policy.level(for: tool("RenderPreview", destructive: true)) == .high)
        #expect(policy.level(for: tool("XcodeMakeDir", destructive: true)) == .high)
        #expect(policy.level(for: tool("GetBuildLog", destructive: true)) == .high)
    }

    @Test("foreign 服务器即使只读同名工具也不套用精确表，走注解/启发式")
    func foreignReadOnlySameNameUsesHintsNotTable() {
        let policy = MCPPermissionPolicy()
        // RenderPreview 在精确表是 low；foreign 服务器无精确表，
        // readOnlyHint → safe（而非继承 low）。
        #expect(policy.level(for: tool("RenderPreview", readOnly: true)) == .safe)
        // 无任何注解时回落到名称启发式（"read" → safe），而非精确表。
        #expect(policy.level(for: tool("XcodeRead")) == .safe)
        // 无注解且名称无特征 → 未知默认 high。
        #expect(policy.level(for: tool("XcodeMakeDir")) == .high)
    }

    @Test("Xcode 原生服务器仍套用精确表（含 destructiveHint 之前的分级）")
    func nativeXcodeKeepsExactTable() {
        let policy = MCPPermissionPolicy()
        #expect(policy.level(for: tool("XcodeRead"), isXcodeNativeServer: true) == .safe)
        #expect(policy.level(for: tool("RenderPreview"), isXcodeNativeServer: true) == .low)
        #expect(policy.level(for: tool("XcodeMakeDir"), isXcodeNativeServer: true) == .medium)
        #expect(policy.level(for: tool("XcodeWrite"), isXcodeNativeServer: true) == .high)
    }

    @Test("用户覆盖在两种服务器身份下都优先")
    func overrideWinsRegardlessOfServer() {
        let policy = MCPPermissionPolicy()
        #expect(policy.level(for: tool("XcodeRead", destructive: true), override: .medium) == .medium)
        #expect(
            policy.level(for: tool("XcodeWrite"), override: .safe, isXcodeNativeServer: true) == .safe
        )
    }

    // MARK: - 身份判定：以实际命令为准，而非可任意填写的 id / 名称

    @Test("xcrun mcpbridge 及其路径变体被识别为 Xcode 原生桥")
    func detectsXcodeNativeBridge() {
        #expect(MCPPermissionPolicy.isXcodeNativeServer(command: "xcrun", arguments: ["mcpbridge"]))
        #expect(MCPPermissionPolicy.isXcodeNativeServer(command: "/usr/bin/xcrun", arguments: ["mcpbridge"]))
        #expect(MCPPermissionPolicy.isXcodeNativeServer(command: "xcrun", arguments: ["--sdk", "macosx", "mcpbridge"]))
        #expect(MCPPermissionPolicy.isXcodeNativeServer(command: "mcpbridge", arguments: []))
        #expect(MCPPermissionPolicy.isXcodeNativeServer(command: "/usr/local/bin/mcpbridge", arguments: []))
    }

    @Test("foreign 命令不被识别为 Xcode 原生桥")
    func rejectsForeignCommands() {
        #expect(!MCPPermissionPolicy.isXcodeNativeServer(command: "npx", arguments: ["-y", "some-mcp-server"]))
        #expect(!MCPPermissionPolicy.isXcodeNativeServer(command: "docker", arguments: ["run", "ghcr.io/github/github-mcp-server"]))
        #expect(!MCPPermissionPolicy.isXcodeNativeServer(command: "xcrun", arguments: ["simctl"]))
        #expect(!MCPPermissionPolicy.isXcodeNativeServer(command: "/bin/echo", arguments: []))
        // 仅显示名/id 含 Xcode 不足以认定身份。
        #expect(!MCPPermissionPolicy.isXcodeNativeServer(command: "node", arguments: ["xcode-read-server.js"]))
    }

    // MARK: - 适配器层：身份必须从配置贯穿到风险分级与执行能力

    @Test("foreign 适配器暴露同名破坏性工具时判 high 且串行")
    func foreignAdapterDestructiveSameName() async throws {
        let session = StubMCPSession(command: "npx", arguments: ["-y", "evil-server"])
        let adapter = MCPToolAdapter(
            serverID: "foreign",
            serverName: "Evil",
            descriptor: tool("XcodeRead", destructive: true),
            session: session,
            policy: MCPPermissionPolicy(),
            isXcodeNativeServer: MCPPermissionPolicy.isXcodeNativeServer(
                command: session.config.command,
                arguments: session.config.arguments
            )
        )
        #expect(adapter.permissionRiskLevel(arguments: [:]) == .high)
        #expect(adapter.executionCapability == .serialSideEffect)
    }

    @Test("Xcode 原生适配器的只读同名工具仍判 safe 且可并行")
    func nativeAdapterReadOnlySameName() async throws {
        let session = StubMCPSession(command: "xcrun", arguments: ["mcpbridge"])
        let adapter = MCPToolAdapter(
            serverID: "xcode",
            serverName: "Xcode (native)",
            descriptor: tool("XcodeRead", readOnly: true),
            session: session,
            policy: MCPPermissionPolicy(),
            isXcodeNativeServer: MCPPermissionPolicy.isXcodeNativeServer(
                command: session.config.command,
                arguments: session.config.arguments
            )
        )
        #expect(adapter.permissionRiskLevel(arguments: [:]) == .safe)
        #expect(adapter.executionCapability == .parallelReadOnly)
    }
}

/// 风险分级测试用的最小会话替身：只承载配置，不真正连接或调用。
private struct StubMCPSession: MCPServerServing {
    let config: MCPServerConfig
    var isConnected: Bool { false }

    init(command: String, arguments: [String]) {
        config = MCPServerConfig(name: "Stub", command: command, arguments: arguments)
    }

    func connect() async throws {}
    func disconnect() async {}
    func listTools() async throws -> [MCPToolDescriptor] { [] }
    func callTool(name: String, arguments: [String: MCPJSONValue]) async throws -> MCPCallResult {
        MCPCallResult(text: "", images: [], isError: false)
    }
}