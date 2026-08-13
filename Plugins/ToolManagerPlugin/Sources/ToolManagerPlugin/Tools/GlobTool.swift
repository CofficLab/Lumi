import Foundation
import KernelLumi

/// Read-only compatibility tool for models that use the conventional Glob name.
public struct GlobTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "glob",
        displayName: "Glob",
        description: "Find files matching a glob pattern under a directory."
    )
    public static let tags: Set<LumiToolTag> = [.fileSystem, .readOnly, .fast]

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "pattern": .object(["type": .string("string"), "description": .string("Glob pattern, for example **/*Conversation*Plugin*.swift")]),
                "path": .object(["type": .string("string"), "description": .string("Absolute directory to search; defaults to the current project root")])
            ]),
            "required": .array([.string("pattern")])
        ])
    }

    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel { .low }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        guard let pattern = arguments["pattern"]?.stringValue, !pattern.isEmpty else {
            return "Error: Missing 'pattern' argument"
        }
        let rootPath = arguments["path"]?.stringValue ?? kernel.currentProjectPath
        guard let rootPath, !rootPath.isEmpty else {
            return "Error: No search path available; provide an absolute 'path'"
        }
        guard kernel.isPathAllowed(rootPath) else {
            return "Error: Path access denied: \(rootPath)"
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
