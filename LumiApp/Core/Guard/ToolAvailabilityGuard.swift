import Foundation

/// 工具可用性守卫：
/// - 仅当聊天模式允许工具，且当前不是 final step 时，返回原工具列表
/// - 其余情况返回空列表
struct ToolAvailabilityGuard {
    func evaluate(tools: [AgentTool], allowsTools: Bool, isFinalStep: Bool) -> [AgentTool] {
        guard allowsTools && !isFinalStep else { return [] }
        return tools
    }
}
