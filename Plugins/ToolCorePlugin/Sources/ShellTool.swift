import Foundation
import LumiCoreKit
import ShellKit

public struct ShellTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "run_command",
        displayName: LumiPluginLocalization.string("Run Command", bundle: .module),
        description: LumiPluginLocalization.string("Execute a shell command in the terminal.", bundle: .module)
    )

    private static let highRiskCommands: Set<String> = [
        "rm", "rmdir", "mv", "sudo", "kill", "killall", "chmod", "chown", "dd", "shutdown", "reboot"
    ]

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "command": .object([
                    "type": .string("string"),
                    "description": .string("The shell command to execute")
                ])
            ]),
            "required": .array([.string("command")])
        ])
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        guard let command = arguments["command"]?.stringValue else {
            return .high
        }
        let base = command
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .first
            .map(String.init)?
            .lowercased() ?? ""
        return Self.highRiskCommands.contains(base) ? .high : .low
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        guard let command = arguments["command"]?.stringValue else {
            return "Run command"
        }
        let preview = command.count > 40 ? String(command.prefix(40)) + "…" : command
        return "Run \(preview)"
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let command = arguments["command"]?.stringValue,
              !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw NSError(domain: "ShellTool", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing command"])
        }

        let options = ShellOptions(
            workingDirectory: context.currentProjectPath,
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
