import Foundation
import OSLog
import SwiftUI

final class PermissionService: Sendable {
    static let shared = PermissionService()
    nonisolated static let verbose = true

    // MARK: - 工具权限检查

    /// 检查工具是否需要权限
    func requiresPermission(toolName: String, arguments: [String: Any]?) -> Bool {
        switch toolName {
        case "write_file":
            // 写文件总是需要权限
            return true

        case "run_command":
            guard let args = arguments,
                  let command = args["command"] as? String else {
                return true  // 默认需要权限
            }
            return evaluateCommandRisk(command: command).requiresPermission

        default:
            return false
        }
    }

    /// 评估命令风险等级（由 ShellTool 提供）
    func evaluateCommandRisk(command: String) -> CommandRiskLevel {
        // 直接调用 ShellTool 的静态方法
        return ShellTool.evaluateCommandRisk(command: command)
    }
}
