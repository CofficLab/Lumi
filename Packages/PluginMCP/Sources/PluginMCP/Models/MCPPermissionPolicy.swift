import Foundation
import KitAgentTool
import KitMCP

/// MCP 工具风险分级策略。
///
/// 判定顺序（前序命中即返回）：
/// 1. 用户单工具覆盖（`MCPServerRegistry.riskOverride`）；
/// 2. 精确规则表（Xcode 原生 mcpbridge 全量工具逐项列出，本机 Xcode 27.0 实测 54 个）；
/// 3. 注解启发：`destructiveHint == true` → `high`（破坏性优先）；
/// 4. 注解启发：`readOnlyHint == true` → `safe`；
/// 5. 名称关键词启发（危险 / 写 / 读）；
/// 6. 未知工具默认（默认 `high`，防止新服务器悄悄获得权限）。
public struct MCPPermissionPolicy: Sendable {
    public let unknownDefault: CommandRiskLevel

    public init(unknownDefault: CommandRiskLevel = .high) {
        self.unknownDefault = unknownDefault
    }

    /// 判定单个工具的风险等级。
    /// - Parameter override: 用户单工具覆盖（`nil` 表示未覆盖）。
    public func level(
        for tool: MCPToolDescriptor,
        override: CommandRiskLevel? = nil
    ) -> CommandRiskLevel {
        if let override { return override }
        if let exact = Self.exactRuleTable[tool.name] { return exact }
        if tool.destructiveHint == true { return .high }
        if tool.readOnlyHint == true { return .safe }
        if let heuristic = Self.heuristicLevel(for: tool.name) { return heuristic }
        return unknownDefault
    }

    // MARK: - Exact Rule Table

    /// 精确规则表：按工具名精确匹配。
    ///
    /// 基于本机 Xcode 27.0 (27A266a) `xcrun mcpbridge` 实测的 54 个工具，
    /// 按语义分类：只读查询 safe / 轻副作用 low / 状态切换与写操作 medium /
    /// 构建运行调试与文件破坏 high。
    public static let exactRuleTable: [String: CommandRiskLevel] = [
        // ── 只读：文件与代码检索 ──
        "XcodeRead": .safe,
        "XcodeGrep": .safe,
        "XcodeGlob": .safe,
        "XcodeLS": .safe,
        "XcodeRefreshCodeIssuesInFile": .safe,
        // ── 只读：工作区与目标查询 ──
        "XcodeListWorkspaces": .safe,
        "XcodeListSchemes": .safe,
        "XcodeListTargets": .safe,
        "XcodeListTemplates": .safe,
        "XcodeListTestPlans": .safe,
        "XcodeListRunDestinations": .safe,
        // ── 只读：构建与诊断查询 ──
        "GetBuildLog": .safe,
        "GetConsoleOutput": .safe,
        "GetTestList": .safe,
        "GetFileCompilerFlags": .safe,
        "GetTargetBuildSettings": .safe,
        "GetCrashIssueLogs": .safe,
        "GetTopCrashIssues": .safe,
        "GetFieldPerformanceIssueLogs": .safe,
        "GetTopFieldPerformanceIssues": .safe,
        "DocumentationSearch": .safe,
        "StringCatalogRead": .safe,
        "StringCatalogContext": .safe,
        "LocalizationPlanner": .safe,
        // ── 低风险：渲染/预览类 ──
        "RenderPreview": .low,
        // ── 中风险：工作区状态切换 / 非破坏性写 ──
        "XcodeMakeDir": .medium,
        "XcodeCloseWorkspace": .medium,
        "XcodeSwitchScheme": .medium,
        "XcodeSwitchRunDestination": .medium,
        "XcodeSwitchTestPlan": .medium,
        "XcodeOpenWorkspace": .medium,
        // ── 高风险：文件破坏 / 构建运行 / 调试 / 设备交互 ──
        "XcodeWrite": .high,
        "XcodeUpdate": .high,
        "XcodeRM": .high,
        "XcodeMV": .high,
        "XcodeNewProject": .high,
        "XcodeNewTarget": .high,
        "AddEntitlement": .high,
        "AddInfoPlist": .high,
        "StringCatalogEdit": .high,
        "UpdateFileCompilerFlags": .high,
        "UpdateTargetBuildSetting": .high,
        "BuildProject": .high,
        "RunProject": .high,
        "StopProject": .high,
        "RunAllTests": .high,
        "RunSomeTests": .high,
        "RunCodeSnippet": .high,
        "InvokeDebuggerCommand": .high,
        "DeviceInteractionStartSession": .high,
        "DeviceInteractionStartWorkspaceSession": .high,
        "DeviceInteractionEndSession": .high,
        "DeviceInteractionInstallAndRun": .high,
        "DeviceInteractionSynthesize": .high,
    ]

    // MARK: - Heuristics

    /// 名称关键词启发（子串匹配，大小写不敏感）。
    /// 危险词优先于写词，写词优先于只读词。
    public static func heuristicLevel(for name: String) -> CommandRiskLevel? {
        let lower = name.lowercased()
        if Self.highKeywords.contains(where: { lower.contains($0) }) { return .high }
        if Self.mediumKeywords.contains(where: { lower.contains($0) }) { return .medium }
        if Self.safeKeywords.contains(where: { lower.contains($0) }) { return .safe }
        return nil
    }

    /// 高危险关键词：删除、移动、破坏、构建、执行、发布、重启等。
    public static let highKeywords: [String] = [
        "delete", "remove", "unlink", "wipe", "truncate",
        "mv", "move", "rename", "destroy", "drop", "format", "purge",
        "build", "install", "execute", "snippet", "shell", "terminal",
        "publish", "deploy", "push", "submit",
        "stop", "kill", "reboot", "restart",
        "write", "update", "patch", "save",
    ]

    /// 中风险关键词：创建、编辑、启动、网络交互等。
    public static let mediumKeywords: [String] = [
        "create", "add", "insert", "append", "edit", "modify",
        "put", "set", "send", "post", "start", "launch", "invoke", "upload",
    ]

    /// 只读关键词：查询、读取、展示等。
    public static let safeKeywords: [String] = [
        "read", "get", "list", "search", "find", "lookup", "query", "fetch",
        "status", "peek", "observe", "preview", "snapshot", "show", "open",
        "inspect", "describe", "info", "log", "history", "diff", "stat",
        "ls", "cat", "grep", "glob", "listwindows", "navigator",
    ]
}
