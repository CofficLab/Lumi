import Foundation
import KitAgentTool

/// 远程命令的风险分级（纯函数，可离线测试）。
///
/// 策略保守：
/// - 含 shell 元字符（管道 / 重定向 / 命令串联 / 命令替换）→ 一律 `.high`，
///   因为只读前缀后面可以接任意写操作。
/// - 首个词落在只读白名单（或只读子命令组合）→ `.medium`。
/// - 其余 → `.high`。
public enum ServerExecRisk {
    /// 只读命令白名单（首个词，小写比较）。
    /// 不含 awk / sed / tee 等可写文件的工具。
    public static let readOnlyCommands: Set<String> = [
        "ls", "cat", "head", "tail", "pwd", "echo", "whoami", "hostname",
        "uname", "uptime", "df", "du", "free", "ps", "grep", "egrep", "fgrep",
        "find", "stat", "wc", "date", "id", "env", "printenv", "which",
        "whereis", "file", "sort", "uniq", "cut", "vmstat", "iostat", "mpstat",
        "netstat", "ss", "ifconfig", "journalctl", "dmesg", "lscpu", "lsblk",
        "lsmod", "last", "w", "who", "groups", "arch", "nproc", "locale",
    ]

    /// 只读子命令组合：首词 + 次词。
    private static let readOnlySubcommands: [String: Set<String>] = [
        "systemctl": ["status", "list-units", "list-unit-files", "is-active", "is-enabled"],
        "docker": ["ps", "logs", "images", "info", "inspect", "stats", "version", "top"],
        "git": ["status", "log", "diff", "branch", "show", "remote", "tag"],
        "ip": ["addr", "route", "link", "neigh"],
        "crontab": ["-l"],
    ]

    /// 出现即升级为高风险的 shell 元字符。
    private static let escalationMarkers = [";", "&&", "||", "|", "`", "$(", ">", "<", "\n"]

    public static func level(for command: String) -> CommandRiskLevel {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .high }
        if escalationMarkers.contains(where: { trimmed.contains($0) }) { return .high }

        let words = trimmed.split(separator: " ").map { $0.lowercased() }
        guard let first = words.first else { return .high }
        if let subcommands = readOnlySubcommands[first],
           words.count >= 2, subcommands.contains(words[1]) {
            return .medium
        }
        if readOnlyCommands.contains(first) { return .medium }
        return .high
    }
}