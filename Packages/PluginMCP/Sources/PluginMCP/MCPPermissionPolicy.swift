import Foundation
import KitAgentTool
import KitMCP

/// MCP 工具风险分级策略。
///
/// 判定顺序（前序命中即返回）：
/// 1. 用户单工具覆盖（`MCPServerRegistry.riskOverride`）；
/// 2. 精确规则表（Xcode 内置预设逐项列出）；
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

    /// 精确规则表：按工具名精确匹配（Xcode 原生 mcpbridge 预设）。
    /// 参考调研文档 5 节工具清单。
    public static let exactRuleTable: [String: CommandRiskLevel] = [
        // 文件操作
        "XcodeRead": .safe,
        "XcodeGrep": .safe,
        "XcodeGlob": .safe,
        "XcodeLS": .safe,
        "XcodeMakeDir": .medium,
        "XcodeWrite": .high,
        "XcodeUpdate": .high,
        "XcodeRM": .high,
        "XcodeMV": .high,
        // 构建与测试
        "GetBuildLog": .safe,
        "GetTestList": .safe,
        "BuildProject": .high,
        "RunAllTests": .high,
        "RunSomeTests": .high,
        // 诊断
        "XcodeListNavigatorIssues": .safe,
        "XcodeRefreshCodeIssuesInFile": .safe,
        // 智能
        "RenderPreview": .low,
        "DocumentationSearch": .safe,
        "ExecuteSnippet": .high,
        // 工作区
        "XcodeListWindows": .safe,
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
