import Foundation
import LumiCoreKit

public struct ListDirectoryTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "ls",
        displayName: LumiPluginLocalization.string("List Directory", bundle: .module),
        description: LumiPluginLocalization.string("List files and directories at a given path. Useful for exploring the project structure.", bundle: .module)
    )
    public static let tags: Set<LumiToolTag> = [.fileSystem, .readOnly, .fast]

    private let maxItems = 500

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "path": .object([
                    "type": .string("string"),
                    "description": .string("The absolute path to the directory to list")
                ]),
                "recursive": .object([
                    "type": .string("boolean"),
                    "description": .string("Whether to list subdirectories recursively. Defaults to false.")
                ])
            ]),
            "required": .array([.string("path")])
        ])
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        guard let path = arguments["path"]?.stringValue else { return "列出目录" }
        let dirName = URL(fileURLWithPath: path).lastPathComponent
        return "列出 \(dirName) 目录"
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let path = arguments["path"]?.stringValue else {
            throw NSError(domain: "ListDirectoryTool", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing 'path' argument"])
        }

        if !context.isPathAllowed(path) {
            throw NSError(
                domain: "ListDirectoryTool",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Path access denied: \(path)\n\n此路径不在允许的文件操作范围内。"]
            )
        }

        let recursive = arguments["recursive"]?.boolValue ?? false
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)

        do {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                return "Error: Directory does not exist: \(url.path)"
            }

            let output = try list(url: url, recursive: recursive)
            return output.lines.joined(separator: "\n") + (output.truncated ? "\n... (truncated)" : "")
        } catch {
            return "Error listing directory: \(error.localizedDescription)"
        }
    }

    private func list(url: URL, recursive: Bool) throws -> (lines: [String], truncated: Bool) {
        var lines: [String] = []
        var truncated = false
        let basePath = url.path

        if recursive {
            guard let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                return ([], false)
            }

            for case let itemURL as URL in enumerator {
                if lines.count >= maxItems {
                    truncated = true
                    break
                }
                lines.append(relativePath(for: itemURL, basePath: basePath))
            }
        } else {
            let items = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            for itemURL in items.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).prefix(maxItems) {
                lines.append(label(for: itemURL))
            }
            truncated = items.count > maxItems
        }

        return (lines, truncated)
    }

    private func relativePath(for url: URL, basePath: String) -> String {
        let path = url.path
        let relative = path.hasPrefix(basePath) ? String(path.dropFirst(basePath.count).drop(while: { $0 == "/" })) : url.lastPathComponent
        return label(for: url, name: relative)
    }

    private func label(for url: URL, name: String? = nil) -> String {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
        return "\(name ?? url.lastPathComponent)\(values?.isDirectory == true ? "/" : "")"
    }
}
