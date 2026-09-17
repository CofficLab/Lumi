import Foundation
import KitAgentTool
import KitMCP
import Testing
@testable import PluginMCP

@Suite("MCPPermissionPolicy")
struct MCPPermissionPolicyTests {
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

    @Test("Xcode 精确规则表逐项匹配（本机 27.0 实测 54 工具）")
    func xcodeExactTable() {
        let policy = MCPPermissionPolicy()
        // 只读查询
        #expect(policy.level(for: tool("XcodeRead")) == .safe)
        #expect(policy.level(for: tool("XcodeGrep")) == .safe)
        #expect(policy.level(for: tool("XcodeGlob")) == .safe)
        #expect(policy.level(for: tool("XcodeLS")) == .safe)
        #expect(policy.level(for: tool("XcodeListWorkspaces")) == .safe)
        #expect(policy.level(for: tool("XcodeListSchemes")) == .safe)
        #expect(policy.level(for: tool("GetBuildLog")) == .safe)
        #expect(policy.level(for: tool("GetTestList")) == .safe)
        #expect(policy.level(for: tool("GetConsoleOutput")) == .safe)
        #expect(policy.level(for: tool("GetTargetBuildSettings")) == .safe)
        #expect(policy.level(for: tool("XcodeRefreshCodeIssuesInFile")) == .safe)
        #expect(policy.level(for: tool("DocumentationSearch")) == .safe)
        #expect(policy.level(for: tool("StringCatalogRead")) == .safe)
        #expect(policy.level(for: tool("LocalizationPlanner")) == .safe)
        // 低风险
        #expect(policy.level(for: tool("RenderPreview")) == .low)
        // 中风险：状态切换
        #expect(policy.level(for: tool("XcodeMakeDir")) == .medium)
        #expect(policy.level(for: tool("XcodeOpenWorkspace")) == .medium)
        #expect(policy.level(for: tool("XcodeSwitchScheme")) == .medium)
        #expect(policy.level(for: tool("XcodeSwitchRunDestination")) == .medium)
        #expect(policy.level(for: tool("XcodeCloseWorkspace")) == .medium)
        // 高风险：构建 / 运行 / 写 / 破坏
        #expect(policy.level(for: tool("BuildProject")) == .high)
        #expect(policy.level(for: tool("RunProject")) == .high)
        #expect(policy.level(for: tool("RunAllTests")) == .high)
        #expect(policy.level(for: tool("RunSomeTests")) == .high)
        #expect(policy.level(for: tool("RunCodeSnippet")) == .high)
        #expect(policy.level(for: tool("InvokeDebuggerCommand")) == .high)
        #expect(policy.level(for: tool("XcodeWrite")) == .high)
        #expect(policy.level(for: tool("XcodeUpdate")) == .high)
        #expect(policy.level(for: tool("XcodeRM")) == .high)
        #expect(policy.level(for: tool("XcodeMV")) == .high)
        #expect(policy.level(for: tool("XcodeNewProject")) == .high)
        #expect(policy.level(for: tool("AddEntitlement")) == .high)
        #expect(policy.level(for: tool("AddInfoPlist")) == .high)
        #expect(policy.level(for: tool("StringCatalogEdit")) == .high)
        #expect(policy.level(for: tool("DeviceInteractionSynthesize")) == .high)
        #expect(policy.level(for: tool("DeviceInteractionInstallAndRun")) == .high)
    }

    @Test("未知工具默认 high，可配置")
    func unknownDefault() {
        let strict = MCPPermissionPolicy()
        #expect(strict.level(for: tool("mystery_tool")) == .high)

        let relaxed = MCPPermissionPolicy(unknownDefault: .medium)
        #expect(relaxed.level(for: tool("mystery_tool")) == .medium)
    }

    @Test("用户覆盖优先于一切规则")
    func overrideWins() {
        let policy = MCPPermissionPolicy()
        #expect(policy.level(for: tool("XcodeWrite"), override: .safe) == .safe)
        #expect(policy.level(for: tool("read_file"), override: .high) == .high)
    }

    @Test("注解启发：破坏性优先 high，只读 safe")
    func annotations() {
        let policy = MCPPermissionPolicy()
        #expect(policy.level(for: tool("foo", destructive: true)) == .high)
        #expect(policy.level(for: tool("foo", readOnly: true)) == .safe)
        // 破坏性优先于只读（名称命中删除场景更安全）。
        #expect(policy.level(for: tool("foo", readOnly: true, destructive: true)) == .high)
    }

    @Test("名称关键词启发")
    func heuristics() {
        let policy = MCPPermissionPolicy()
        // 危险词 → high
        #expect(policy.level(for: tool("delete_file")) == .high)
        #expect(policy.level(for: tool("execute_snippet")) == .high)
        #expect(policy.level(for: tool("restart_service")) == .high)
        #expect(policy.level(for: tool("write_file")) == .high)
        // 写词 → medium
        #expect(policy.level(for: tool("create_folder")) == .medium)
        #expect(policy.level(for: tool("send_message")) == .medium)
        #expect(policy.level(for: tool("launch_app")) == .medium)
        // 只读词 → safe
        #expect(policy.level(for: tool("get_status")) == .safe)
        #expect(policy.level(for: tool("list_files")) == .safe)
        #expect(policy.level(for: tool("search_code")) == .safe)
        #expect(policy.level(for: tool("peek_window")) == .safe)
    }

    @Test("危险词优先于只读词（同一名称含两个特征）")
    func dangerBeforeRead() {
        let policy = MCPPermissionPolicy()
        // "delete" 命中 high，即使含 "list"。
        #expect(policy.level(for: tool("delete_list")) == .high)
        #expect(MCPPermissionPolicy.heuristicLevel(for: "list_delete") == .high)
    }
}
