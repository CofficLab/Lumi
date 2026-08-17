import AgentToolKit
import Foundation
import ShellKit

/// 执行终端命令（复刻旧版 ToolManagerPlugin 的 ShellTool）。
public struct ShellTool: SuperAgentTool, @unchecked Sendable {
    public let name = "run_command"

    private static let highRiskCommands: Set<String> = [
        "rm", "rmdir", "mv", "sudo", "kill", "killall", "chmod", "chown", "dd", "shutdown", "reboot"
    ]
    private let commandTimeout: TimeInterval

    public init(commandTimeout: TimeInterval = 120) {
        self.commandTimeout = commandTimeout
    }

    public func description(for language: LanguagePreference) -> String {
        "Execute a shell command in the terminal."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "command": ["type": "string", "description": "The shell command to execute"],
                "timeout": ["type": "integer", "description": "Optional timeout in seconds (default: 120)"],
            ],
            "required": ["command"],
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        guard let command = arguments.stringValue("command") else { return .high }
        let base = command
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .first
            .map(String.init)?
            .lowercased() ?? ""
        return Self.highRiskCommands.contains(base) ? .high : .low
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let command = arguments.stringValue("command") else { return "运行命令" }
        let preview = command.count > 40 ? String(command.prefix(40)) + "…" : command
        return "运行 \(preview)"
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let command = arguments.stringValue("command"),
              !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw NSError(domain: "ShellTool", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing command"])
        }

        let timeout = TimeInterval(arguments.intValue("timeout") ?? Int(commandTimeout))

        let options = ShellOptions(
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            timeout: timeout,
            throwsOnError: false
        )
        let result = try await ShellExecutor.execute(
            executable: "/bin/zsh",
            arguments: ["-lc", command],
            options: options
        )

        if result.exitCode != 0 {
            return "Exit code: \(result.exitCode)\n\(result.stdout)\n\(result.stderr)"
        }

        let combined = (result.stdout + result.stderr).trimmingCharacters(in: .whitespacesAndNewlines)
        return combined.isEmpty ? "Command completed successfully." : combined
    }
}
