import Foundation
import OSLog
import SwiftUI
import Combine

final class PermissionService: ObservableObject, Sendable {
    static let shared = PermissionService()
    nonisolated static let verbose = true

    init() {}

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

    /// 评估命令风险等级
    func evaluateCommandRisk(command: String) -> CommandRiskLevel {
        return CommandRiskEvaluator.evaluate(command: command)
    }
}
