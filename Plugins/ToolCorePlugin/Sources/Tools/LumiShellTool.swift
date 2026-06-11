import Foundation
import LumiCoreKit

public struct LumiShellTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "run_command",
        displayName: String(localized: "Run Command", bundle: .module),
        description: String(localized: "Execute a shell command in the terminal.", bundle: .module)
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
            throw NSError(domain: "LumiShellTool", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing command"])
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            return "Exit code: \(process.terminationStatus)\n\(output)\n\(errorOutput)"
        }

        let combined = (output + errorOutput).trimmingCharacters(in: .whitespacesAndNewlines)
        return combined.isEmpty ? "Command completed successfully." : combined
    }
}
