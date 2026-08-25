import KitAgentTool
import Foundation

/// Glob 文件匹配。
public struct GlobTool: SuperAgentTool, @unchecked Sendable {
    public let name = "glob"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Find files matching a glob pattern under a directory."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "pattern": ["type": "string", "description": "Glob pattern, for example **/*Conversation*Plugin*.swift"],
                "path": ["type": "string", "description": "Absolute directory to search; defaults to the current working directory"],
            ],
            "required": ["pattern"],
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let pattern = arguments.stringValue("pattern") else { return "搜索文件" }
        return "搜索 \(pattern)"
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let pattern = arguments.stringValue("pattern"), !pattern.isEmpty else {
            return "Error: Missing 'pattern' argument"
        }
        let rootPath = arguments.stringValue("path")
            ?? FileManager.default.currentDirectoryPath
        guard !rootPath.isEmpty else {
            return "Error: No search path available; provide an absolute 'path'"
        }

        let rootURL = URL(fileURLWithPath: (rootPath as NSString).expandingTildeInPath).standardizedFileURL
        guard FileManager.default.fileExists(atPath: rootURL.path) else {
            return "Error: Directory does not exist: \(rootURL.path)"
        }

        let regex = try Self.regex(for: pattern)
        let matches = Self.findMatches(rootURL: rootURL, regex: regex)
        return matches.isEmpty ? "No files matched pattern \(pattern)" : matches.joined(separator: "\n")
    }

    private static func findMatches(rootURL: URL, regex: NSRegularExpression) -> [String] {
        var matches: [String] = []
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }
        for case let url as URL in enumerator {
            let relative = String(url.path.dropFirst(rootURL.path.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if regex.firstMatch(in: relative, range: NSRange(location: 0, length: (relative as NSString).length)) != nil {
                matches.append(relative)
                if matches.count == 500 { break }
            }
        }
        return matches
    }

    private static func regex(for glob: String) throws -> NSRegularExpression {
        var expression = "^"
        var index = glob.startIndex
        while index < glob.endIndex {
            let character = glob[index]
            if character == "*" {
                let next = glob.index(after: index)
                if next < glob.endIndex && glob[next] == "*" {
                    expression += ".*"
                    index = glob.index(after: next)
                    continue
                }
                expression += "[^/]*"
            } else if character == "?" {
                expression += "[^/]"
            } else {
                expression += NSRegularExpression.escapedPattern(for: String(character))
            }
            index = glob.index(after: index)
        }
        return try NSRegularExpression(pattern: expression + "$")
    }
}
