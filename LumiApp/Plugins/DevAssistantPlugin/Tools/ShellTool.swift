import Foundation
import OSLog
import MagicKit
import SwiftUI

struct ShellTool: AgentTool, SuperLog {
    nonisolated static let emoji = "🔧"
    nonisolated static let verbose = true

    let name = "run_command"
    let description = "Execute a shell command in terminal. Use this to run build commands, git commands, or other system tools."

    var inputSchema: [String: Any] {
        return [
            "type": "object",
            "properties": [
                "command": [
                    "type": "string",
                    "description": "The command string to execute (e.g., 'git status')"
                ]
            ],
            "required": ["command"]
        ]
    }

    // We inject existing ShellService to reuse its logic
    private let shellService: ShellService

    init(shellService: ShellService) {
        self.shellService = shellService
    }

    func execute(arguments: [String: Any]) async throws -> String {
        guard let command = arguments["command"] as? String else {
            throw NSError(domain: "ShellTool", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing 'command' argument"])
        }

        // 评估命令风险
        let riskLevel = Self.evaluateCommandRisk(command: command)
        if Self.verbose {
            os_log("命令风险评估 \(command) -> \(riskLevel.displayName)")
        }

        // 检查权限（由外部 PermissionService 调用）
        // 如果需要权限，会在调用 execute 之前拦截

        do {
            let output = try await shellService.execute(command)
            return output
        } catch {
            return "Error executing command: \(error.localizedDescription)"
        }
    }

    // MARK: - 风险评估

    /// 评估命令风险等级（静态方法，供 PermissionService 调用）
    static func evaluateCommandRisk(command: String) -> CommandRiskLevel {
        // 提取第一个命令（去除管道和重定向）
        let firstCommand = command.components(separatedBy: " ").first?
            .components(separatedBy: "|").first?
            .components(separatedBy: "&&").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // 提取命令名称
        let commandName = firstCommand.components(separatedBy: " ").first ?? ""

        // 高风险命令列表
        let highRiskCommands = [
            "rm", "rmdir",           // 删除
            "mv", "cp",                  // 移动/复制（可能覆盖）
            "dd", "mkfs", "format",    // 磁盘操作
            "kill", "killall",          // 终止进程
            "reboot", "shutdown",         // 系统重启
            "sudo", "doas"              // 权限提升
        ]

        // 中风险命令列表
        let mediumRiskCommands = [
            "curl", "wget", "fetch",    // 网络请求
            "brew", "npm", "pip",      // 包管理器
            "git", "svn",                // 版本控制（推送）
            "chmod", "chown"            // 权限修改
        ]

        // 低风险命令列表
        let lowRiskCommands = [
            "ls", "find", "locate",     // 文件浏览
            "cat", "head", "tail",       // 文件读取
            "grep", "awk", "sed",        // 文本处理
            "git status", "git log",    // Git 只读操作
        ]

        // 安全命令列表
        let safeCommands = [
            "echo", "pwd", "date",      // 简单命令
            "whoami", "id", "uname",     // 系统信息
            "git diff", "git show"     // Git 查看
        ]

        // 检查风险等级
        if highRiskCommands.contains(commandName) {
            return .high
        }

        if mediumRiskCommands.contains(commandName) {
            return .medium
        }

        if lowRiskCommands.contains(commandName) {
            return .low
        }

        if safeCommands.contains(commandName) {
            return .safe
        }

        // 未知命令，保守处理
        return .medium
    }
}
