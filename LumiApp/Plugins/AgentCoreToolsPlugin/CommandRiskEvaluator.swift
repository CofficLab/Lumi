import Foundation

/// 命令风险评估工具
enum CommandRiskEvaluator {
    private static let highRiskCommands: Set<String> = [
        "rm", "rmdir", "mv", "cp",
        "dd", "mkfs", "format",
        "kill", "killall", "reboot", "shutdown",
        "sudo", "doas", "chown", "chmod",
        "nc", "ncat", "netcat"  // 可被用于数据外泄或反弹 shell
    ]

    private static let mediumRiskCommands: Set<String> = [
        "curl", "wget", "fetch", "brew", "npm", "pip", "git", "svn"
    ]

    private static let lowRiskCommands: Set<String> = [
        "ls", "find", "locate", "cat", "head", "tail", "grep", "awk", "sed"
    ]

    private static let safeCommands: Set<String> = [
        "echo", "pwd", "date", "whoami", "id", "uname"
    ]

    /// 将整条命令按管道、重定向、连接符拆成多个子命令，并取每个子命令的首词（命令名）。
    private static func commandNamesInChain(_ command: String) -> [String] {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        // 按 | && || ; 换行 拆成段
        var parts: [String] = [trimmed]
        for sep in ["||", "&&", "|", ";", "\n"] {
            parts = parts.flatMap { $0.components(separatedBy: sep) }
        }
        var names: [String] = []
        var seen = Set<String>()
        for part in parts {
            let segment = part.trimmingCharacters(in: .whitespaces)
            let withoutRedirect: String
            if let idx = segment.firstIndex(of: ">") {
                withoutRedirect = String(segment[..<idx]).trimmingCharacters(in: .whitespaces)
            } else {
                withoutRedirect = segment
            }
            let firstWord = withoutRedirect.split(separator: " ", maxSplits: 1).first.map(String.init) ?? ""
            if !firstWord.isEmpty, seen.insert(firstWord).inserted {
                names.append(firstWord)
            }
        }
        return names.isEmpty ? [trimmed.split(separator: " ").first.map(String.init) ?? ""] : names
    }

    /// 检查危险参数/模式，整条命令若匹配则视为高风险。
    private static func hasDangerousPatterns(_ command: String) -> Bool {
        let lower = command.lowercased()
        let normalized = " " + lower + " "

        // rm -rf / 或 rm -rf /* 或 sudo rm -rf 等
        if (normalized.contains(" rm ") || normalized.hasPrefix("rm ")) {
            if (lower.contains("-rf") || lower.contains("-r ") || lower.contains("-f ")) {
                if lower.contains("/") || lower.contains("*") || lower.contains("..") {
                    return true
                }
            }
        }
        if lower.contains("sudo") && (lower.contains("rm ") && (lower.contains("-r") || lower.contains("-f"))) {
            if lower.contains("/") || lower.contains("..") { return true }
        }

        // curl|sh / wget|sh 等远程脚本执行
        if (lower.contains("curl") || lower.contains("wget")) && lower.contains("|") {
            if lower.contains("| sh") || lower.contains("|sh") || lower.contains("| bash") || lower.contains("|bash") {
                return true
            }
        }

        return false
    }

    /// 路径穿越
    private static func hasPathTraversal(_ command: String) -> Bool {
        command.contains("..") && (command.contains("/") || command.hasPrefix(".."))
    }

    /// 评估命令风险等级
    ///
    /// 根据命令名称和特性评估执行风险；会解析管道、重定向、&&、||，对链中每个命令分别评估并取最高风险。
    /// 采用保守策略，未知命令默认为中等风险。
    ///
    /// - Parameter command: 要执行的命令字符串
    /// - Returns: 风险等级
    static func evaluate(command: String) -> CommandRiskLevel {
        if hasDangerousPatterns(command) { return .high }
        if hasPathTraversal(command) { return .high }

        let names = commandNamesInChain(command)
        var level: CommandRiskLevel = .safe

        for name in names {
            let l = riskForCommandName(name)
            if l == .high { return .high }
            if severity(l) > severity(level) { level = l }
        }
        return level
    }

    private static func severity(_ level: CommandRiskLevel) -> Int {
        switch level {
        case .safe: return 0
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }

    private static func riskForCommandName(_ name: String) -> CommandRiskLevel {
        let base = name.lowercased()
        if highRiskCommands.contains(base) { return .high }
        if mediumRiskCommands.contains(base) { return .medium }
        if lowRiskCommands.contains(base) { return .low }
        if safeCommands.contains(base) { return .safe }
        return .medium
    }
}