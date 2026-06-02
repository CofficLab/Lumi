import Foundation
import AgentToolKit

/// 命令风险评估工具
public enum CommandRiskEvaluator {
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
        var names: [String] = []
        var seen = Set<String>()
        for part in shellCommandSegments(trimmed) {
            if let name = commandName(in: part), seen.insert(name).inserted {
                names.append(name)
            }
        }
        return names.isEmpty ? [trimmed.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? ""] : names
    }

    private static func commandName(in segment: String) -> String? {
        let trimmed = segment.trimmingCharacters(in: .whitespaces)
        let withoutRedirect = prefixBeforeUnquotedRedirect(trimmed).trimmingCharacters(in: .whitespaces)
        return withoutRedirect
            .split(whereSeparator: { $0.isWhitespace })
            .first
            .map(String.init)
    }

    private static func shellCommandSegments(_ command: String) -> [String] {
        let characters = Array(command)
        var segments: [String] = []
        var current = ""
        var inSingleQuote = false
        var inDoubleQuote = false
        var escaped = false
        var index = 0

        func finishSegment() {
            let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                segments.append(trimmed)
            }
            current = ""
        }

        while index < characters.count {
            let character = characters[index]

            if escaped {
                current.append(character)
                escaped = false
                index += 1
                continue
            }

            if character == "\\" && !inSingleQuote {
                current.append(character)
                escaped = true
                index += 1
                continue
            }

            if character == "'" && !inDoubleQuote {
                inSingleQuote.toggle()
                current.append(character)
                index += 1
                continue
            }

            if character == "\"" && !inSingleQuote {
                inDoubleQuote.toggle()
                current.append(character)
                index += 1
                continue
            }

            if !inSingleQuote && !inDoubleQuote {
                if character == "\n" || character == ";" || character == "|" {
                    finishSegment()
                    if character == "|", index + 1 < characters.count, characters[index + 1] == "|" {
                        index += 1
                    }
                    index += 1
                    continue
                }

                if character == "&", index + 1 < characters.count, characters[index + 1] == "&" {
                    finishSegment()
                    index += 2
                    continue
                }
            }

            current.append(character)
            index += 1
        }

        finishSegment()
        return segments
    }

    private static func prefixBeforeUnquotedRedirect(_ segment: String) -> String {
        var inSingleQuote = false
        var inDoubleQuote = false
        var escaped = false

        for index in segment.indices {
            let character = segment[index]

            if escaped {
                escaped = false
                continue
            }

            if character == "\\" && !inSingleQuote {
                escaped = true
                continue
            }

            if character == "'" && !inDoubleQuote {
                inSingleQuote.toggle()
                continue
            }

            if character == "\"" && !inSingleQuote {
                inDoubleQuote.toggle()
                continue
            }

            if character == ">" && !inSingleQuote && !inDoubleQuote {
                return String(segment[..<index])
            }
        }

        return segment
    }

    /// 检查危险参数/模式，整条命令若匹配则视为高风险。
    private static func hasDangerousPatterns(_ command: String) -> Bool {
        let segments = shellCommandSegments(command)

        // rm -rf / 或 rm -rf /* 或 sudo rm -rf 等
        for segment in segments {
            let segmentLower = segment.lowercased()
            let normalized = " " + segmentLower + " "
            let name = commandName(in: segment)?.lowercased()

            if name == "rm" {
                if (segmentLower.contains("-rf") || segmentLower.contains("-r ") || segmentLower.contains("-f ")) &&
                    (segmentLower.contains("/") || segmentLower.contains("*") || segmentLower.contains("..")) {
                    return true
                }
            }

            if (name == "sudo" || name == "doas") &&
                normalized.contains(" rm ") &&
                (segmentLower.contains("-r") || segmentLower.contains("-f")) &&
                (segmentLower.contains("/") || segmentLower.contains("..")) {
                return true
            }
        }

        // curl|sh / wget|sh 等远程脚本执行
        let names = segments.compactMap { commandName(in: $0)?.lowercased() }
        for pair in zip(names, names.dropFirst()) {
            if ["curl", "wget"].contains(pair.0) && ["sh", "bash", "zsh"].contains(pair.1) {
                return true
            }
        }

        return false
    }

    /// 路径穿越
    private static func hasPathTraversal(_ command: String) -> Bool {
        shellCommandSegments(command).contains { segment in
            guard let name = commandName(in: segment)?.lowercased(), !safeCommands.contains(name) else {
                return false
            }
            return segment.contains("..") && (segment.contains("/") || segment.hasPrefix(".."))
        }
    }

    /// 评估命令风险等级
    ///
    /// 根据命令名称和特性评估执行风险；会解析管道、重定向、&&、||，对链中每个命令分别评估并取最高风险。
    /// 采用保守策略，未知命令默认为中等风险。
    ///
    /// - Parameter command: 要执行的命令字符串
    /// - Returns: 风险等级
    public static func evaluate(command: String) -> CommandRiskLevel {
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
