/// ToolManager 对一次工具调用作出的授权/执行决策。
public enum ToolAuthorizationDecision: Sendable, Equatable {
    case blocked(reason: String)
    case autoApproved
    case requiresUserApproval
}
