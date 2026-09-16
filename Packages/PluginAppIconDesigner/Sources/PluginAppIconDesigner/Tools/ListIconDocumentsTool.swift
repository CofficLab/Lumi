import KitAgentTool
import Foundation

/// 列出当前项目中的插件管理图标文档。
public struct ListIconDocumentsTool: SuperAgentTool {
    public let name = "list_icon_documents"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "List plugin-managed app icon documents in the current project."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "scope": [
                    "type": "string",
                    "enum": IconScope.allCases.map(\.rawValue),
                    "description": "Filter by storage scope. Only 'project' is supported.",
                ],
            ],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "List icon documents"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let scopeFilter = (IconToolSupport.string(arguments, "scope") ?? IconScope.project.rawValue)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let snapshot = await MainActor.run { () -> [(IconScope, [IconDocument])] in
            // 列表以磁盘为准，确保 Agent 看到最新内容（包括尚未载入内存的文档）。
            var result: [(IconScope, [IconDocument])] = []
            let store = IconDocumentStore.shared
            if scopeFilter == IconScope.project.rawValue {
                let docs = IconDocumentFileStore.loadAll(storagePath: store.projectStoragePath)
                result.append((.project, docs))
            }
            return result
        }

        let lines = snapshot.flatMap { scope, documents in
            documents.isEmpty
                ? ["[scope=\(scope.rawValue)] (no documents)"]
                : documents.map { Self.documentSummary($0, scope: scope) }
        }
        if lines.isEmpty {
            return "No app icon documents found."
        }
        return lines.joined(separator: "\n")
    }

    private static func documentSummary(_ document: IconDocument, scope: IconScope) -> String {
        let layers = document.layers.map { $0.id }.joined(separator: ",")
        return "scope=\(scope.rawValue) documentId=\(document.id) title=\(document.title) size=\(Int(document.width))x\(Int(document.height)) layers=\(document.layers.count)[\(layers)] updatedAt=\(ISO8601DateFormatter().string(from: document.updatedAt))"
    }
}
