import Foundation

/// 命令风险评估工具（由核心工具插件提供，内核不参与具体策略）。
enum CommandRiskEvaluator {
    /// 评估命令风险等级
    ///
    /// 根据命令名称和特性评估执行风险。
    /// 采用保守策略，未知命令默认为中等风险。
    ///
    /// - Parameter command: 要执行的命令字符串
    /// - Returns: 风险等级
    static func evaluate(command: String) -> CommandRiskLevel {
        let firstCommand = command.components(separatedBy: " ").first?
            .components(separatedBy: "|").first?
            .components(separatedBy: "&&").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let commandName = firstCommand.components(separatedBy: " ").first ?? ""

        let highRiskCommands = [
            "rm", "rmdir",
            "mv", "cp",
            "dd", "mkfs", "format",
            "kill", "killall",
            "reboot", "shutdown",
            "sudo", "doas"
        ]

        let mediumRiskCommands = [
            "curl", "wget", "fetch",
            "brew", "npm", "pip",
            "git", "svn",
            "chmod", "chown"
        ]

        let lowRiskCommands = [
            "ls", "find", "locate",
            "cat", "head", "tail",
            "grep", "awk", "sed",
            "git status", "git log"
        ]

        let safeCommands = [
            "echo", "pwd", "date",
            "whoami", "id", "uname",
            "git diff", "git show"
        ]

        if highRiskCommands.contains(commandName) { return .high }
        if mediumRiskCommands.contains(commandName) { return .medium }
        if lowRiskCommands.contains(commandName) { return .low }
        if safeCommands.contains(commandName) { return .safe }
        return .medium
    }
}

