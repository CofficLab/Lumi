import KitAgentTool
import Foundation
import KernelCore
import ProviderToolManager
import KitShell

@MainActor
public final class BrowserSuperPlugin: SuperPlugin {
    public let id = "Browser"
    public let order = 102
    public let metadata = PluginMetadata(
        id: "Browser",
        name: "Browser",
        description: "Control web browser for viewing and interacting with web pages.",
        category: .integration,
        stage: .preview,
        policy: .alwaysOn
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ToolManagerProviding).self)?.add(
            BrowserAgentV2Tool(),
            pluginID: id
        )
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ToolManagerProviding).self)?.remove(id: BrowserAgentV2Tool.toolName)
    }
}

public struct BrowserAgentV2Tool: SuperAgentTool {
    public static let toolName = "browser_agent"
    public let name = toolName

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Browser automation using agent-browser CLI. Supports navigation, element interaction, page snapshots, screenshots, PDFs, JavaScript, and cookies."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "command": ["type": "string", "description": "agent-browser command, such as 'open https://example.com', 'snapshot', or 'click @e1'"],
                "timeout": ["type": "integer", "minimum": 1, "maximum": 300],
            ],
            "required": ["command"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "浏览器自动化"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let command = arguments["command"]?.value as? String else {
            return "Error: Missing required 'command' parameter"
        }
        guard let commandArguments = Self.parseCommandArguments(command), !commandArguments.isEmpty else {
            return "Error: Command contains an unterminated quote or no arguments"
        }
        guard let executable = await Self.findAgentBrowser() else {
            return Self.installationGuide
        }

        let timeout = Self.normalizedTimeout(arguments["timeout"]?.value)
        do {
            let result = try await ShellExecutor.execute(
                executable: executable,
                arguments: commandArguments,
                options: .init(timeout: timeout, throwsOnError: false)
            )
            if result.exitCode == 0 {
                return result.stdout.isEmpty ? "Command completed successfully" : result.stdout
            }
            return "Error: \(result.stderr.isEmpty ? "Command failed with exit code \(result.exitCode)" : result.stderr)"
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }

    static func normalizedTimeout(_ value: Any?) -> TimeInterval {
        let requested = (value as? Int) ?? (value as? Double).map(Int.init) ?? (value as? String).flatMap(Int.init) ?? 30
        return TimeInterval(min(max(requested, 1), 300))
    }

    static func parseCommandArguments(_ command: String) -> [String]? {
        var arguments: [String] = []
        var current = ""
        var quote: Character?
        var escaping = false
        var hasArgument = false

        for character in command {
            if escaping {
                current.append(character)
                hasArgument = true
                escaping = false
            } else if character == "\\" {
                escaping = true
                hasArgument = true
            } else if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                } else {
                    current.append(character)
                    hasArgument = true
                }
            } else if character == "\"" || character == "'" {
                quote = character
                hasArgument = true
            } else if character.isWhitespace {
                if hasArgument { arguments.append(current); current = ""; hasArgument = false }
            } else {
                current.append(character)
                hasArgument = true
            }
        }

        guard quote == nil else { return nil }
        if escaping { current.append("\\") }
        if hasArgument { arguments.append(current) }
        return arguments
    }

    private static func findAgentBrowser() async -> String? {
        if let path = await ShellExecutor.findCommand("agent-browser") { return path }
        for path in ["/opt/homebrew/bin/agent-browser", "/usr/local/bin/agent-browser", "/usr/bin/agent-browser", "/Users/\(NSUserName())/.volta/bin/agent-browser"] {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        let result = try? await ShellExecutor.execute(executable: "/bin/zsh", arguments: ["-l", "-c", "which agent-browser"], options: .init(timeout: 5, throwsOnError: false))
        let path = result?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return result?.isSuccess == true && !path.isEmpty ? path : nil
    }

    private static let installationGuide = """
    Error: agent-browser is not installed on this system.

    Install it with `npm install -g agent-browser`, then run `agent-browser install` once to download Chrome.
    """
}
