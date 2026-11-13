import KitAgentTool

/// 子代理委托的共享契约（#1313）。
///
/// PluginSubagent 用它注册委托工具，PluginAgentLoop 用它过滤子会话的
/// 工具表——两侧引用同一份常量与规则，避免硬编码字符串各自漂移。
public enum SubagentToolPolicy {
    /// 委托工具名。子会话工具表永远不包含它自身（禁止递归）。
    public static let delegationToolName = "run_subagent"

    /// 代理间通信工具名（#1328）。它带副作用，但子会话必须能主动联系
    /// 兄弟或 lead，因此单独允许进入子工具表。
    public static let messagingToolName = "send_subagent_message"

    /// 子会话只拿只读并发工具与显式放行的通信工具：副作用与交互工具
    /// 一律不进子回合，委托工具自身也被排除，递归在契约层就不可能发生。
    public static func childTools(from tools: [any SuperAgentTool]) -> [any SuperAgentTool] {
        tools.filter { tool in
            tool.name != delegationToolName
                && (tool.executionCapability == .parallelReadOnly
                    || tool.name == messagingToolName)
        }
    }
}