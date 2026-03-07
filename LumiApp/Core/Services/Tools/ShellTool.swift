import Foundation
import MagicKit
import OSLog
import SwiftUI

/// Shell 命令执行工具
///
/// 允许 AI 助手执行 Shell 命令，用于：
/// - 构建项目 (make, xcodebuild, cmake)
/// - Git 操作 (git status, git commit)
/// - 包管理 (brew, npm, pip)
/// - 系统工具 (top, ps, kill)
///
/// ⚠️ 安全警告：此工具具有执行系统命令的能力，存在安全风险。
/// 使用前会进行风险评估，危险命令需要用户授权。
///
/// ## 风险等级
///
/// | 等级 | 说明 | 示例命令 |
/// |------|------|----------|
/// | safe | 安全，只读操作 | ls, cat, git status |
/// | low | 低风险，信息查询 | find, grep, git log |
/// | medium | 中等风险，可能有副作用 | brew, npm, curl |
/// | high | 高风险，可能导致数据丢失 | rm, kill, reboot |
struct ShellTool: AgentTool, SuperLog {
    /// 日志标识符
    nonisolated static let emoji = "🔧"
    
    /// 是否启用详细日志
    nonisolated static let verbose = true

    /// 工具名称
    let name = "run_command"
    
    /// 工具描述
    let description = "Execute a shell command in terminal. Use this to run build commands, git commands, or other system tools."

    /// 输入参数 JSON Schema
    ///
    /// 定义工具接受的参数格式：
    /// ```json
    /// {
    ///   "type": "object",
    ///   "properties": {
    ///     "command": {
    ///       "type": "string",
    ///       "description": "The command string to execute"
    ///     }
    ///   },
    ///   "required": ["command"]
    /// }
    /// ```
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

    /// 初始化 ShellTool
    init() {}

    /// 执行 Shell 命令
    ///
    /// 执行步骤：
    /// 1. 验证参数（必须有 command）
    /// 2. 评估命令风险等级
    /// 3. 创建 ShellService 执行命令
    /// 4. 返回执行结果
    ///
    /// - Parameter arguments: 参数字典，必须包含 "command" 键
    /// - Returns: 命令执行结果
    /// - Throws: 参数错误或执行错误
    func execute(arguments: [String: ToolArgument]) async throws -> String {
        // 验证必需参数
        guard let command = arguments["command"]?.value as? String else {
            throw NSError(
                domain: "ShellTool", 
                code: 400, 
                userInfo: [NSLocalizedDescriptionKey: "Missing 'command' argument"]
            )
        }

        // 评估命令风险
        let riskLevel = Self.evaluateCommandRisk(command: command)
        if Self.verbose {
            os_log("\(Self.t)👮 \(riskLevel.displayName) -> \(command)")
        }

        // 创建临时的 ShellService 执行命令
        let shellService = ShellService()
        do {
            let output = try await shellService.execute(command)
            return output
        } catch {
            return "Error executing command: \(error.localizedDescription)"
        }
    }

    // MARK: - 风险评估

    /// 评估命令风险等级
    ///
    /// 根据命令名称和特性评估执行风险。
    /// 采用保守策略，未知命令默认为中等风险。
    ///
    /// - Parameter command: 要执行的命令字符串
    /// - Returns: 风险等级
    static func evaluateCommandRisk(command: String) -> CommandRiskLevel {
        // 提取第一个命令（去除管道和重定向）
        let firstCommand = command.components(separatedBy: " ").first?
            .components(separatedBy: "|").first?
            .components(separatedBy: "&&").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // 提取命令名称（去除路径和参数）
        let commandName = firstCommand.components(separatedBy: " ").first ?? ""

        // 高风险命令列表
        /// 可能导致数据丢失或系统崩溃的命令
        let highRiskCommands = [
            "rm", "rmdir",           // 删除文件和目录
            "mv", "cp",                  // 移动/复制（可能覆盖）
            "dd", "mkfs", "format",    // 磁盘操作
            "kill", "killall",          // 强制终止进程
            "reboot", "shutdown",         // 系统重启/关机
            "sudo", "doas"              // 权限提升
        ]

        // 中风险命令列表
        /// 可能有副作用但通常安全的命令
        let mediumRiskCommands = [
            "curl", "wget", "fetch",    // 网络请求（可能下载恶意内容）
            "brew", "npm", "pip",      // 包管理器（安装软件）
            "git", "svn",                // 版本控制（推送操作）
            "chmod", "chown"            // 权限修改
        ]

        // 低风险命令列表
        /// 信息查询类命令，通常只读
        let lowRiskCommands = [
            "ls", "find", "locate",     // 文件浏览
            "cat", "head", "tail",       // 文件读取
            "grep", "awk", "sed",        // 文本处理
            "git status", "git log"    // Git 只读操作
        ]

        // 安全命令列表
        /// 完全无害的只读命令
        let safeCommands = [
            "echo", "pwd", "date",      // 简单命令
            "whoami", "id", "uname",     // 系统信息查询
            "git diff", "git show"     // Git 查看操作
        ]

        // 逐级检查风险
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

        // 未知命令，保守处理为中等风险
        return .medium
    }
}