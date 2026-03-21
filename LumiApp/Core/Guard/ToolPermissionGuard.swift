import Foundation

/// 工具权限守卫：
/// - 需要权限且未开启 auto-approve 时，返回权限请求
/// - 其余情况允许直接执行
struct ToolPermissionGuard {
    enum Result {
        case proceed
        case permissionRequired(PermissionRequest)
    }

    func evaluate(
        toolCall: ToolCall,
        autoApproveRisk: Bool,
        requiresPermission: Bool,
        riskLevel: CommandRiskLevel
    ) -> Result {
        guard requiresPermission && !autoApproveRisk else {
            return .proceed
        }

        return .permissionRequired(
            PermissionRequest(
                toolName: toolCall.name,
                argumentsString: toolCall.arguments,
                toolCallID: toolCall.id,
                riskLevel: riskLevel
            )
        )
    }
}
