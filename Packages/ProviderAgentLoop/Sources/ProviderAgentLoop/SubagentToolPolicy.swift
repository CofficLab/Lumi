import KitAgentTool

/// 子代理委托的共享契约（#1313）。
///
/// PluginSubagent 用它注册委托工具，PluginAgentLoop 用它过滤子会话的
/// 工具表——两侧引用同一份常量与规则，避免硬编码字符串各自漂移。
public enum SubagentToolPolicy {
    /// 委托工具名。子会话工具表永远不包含它自身（禁止递归）。
    public static let delegationToolName = "run_subagent"

    /// 子会话只拿只读并发工具：副作用与交互工具一律不进子回合，
    /// 委托工具自身也被排除，递归在契约层就不可能发生。
    public static func childTools(from tools: [any SuperAgentTool]) -> [any SuperAgentTool] {
        tools.filter { tool in
            tool.name != delegationToolName && tool.executionCapability == .parallelReadOnly
        }
    }
}