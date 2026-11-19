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
        guard scopeFilter == IconScope.project.rawValue else {
            return "No app icon documents found."
        }

        // 存储路径在主线程读取（廉价属性），全量磁盘扫描放到主线程之外，
        // 避免每次列表调用都在主线程扫描并解码全部文档（#1292）。
        let storagePath = await MainActor.run { IconToolSupport.store().projectStoragePath }
        let documents = IconDocumentFileStore.loadAll(storagePath: storagePath)
        if documents.isEmpty {
            return "[scope=\(IconScope.project.rawValue)] (no documents)"
        }
        return documents
            .map { Self.documentSummary($0, scope: .project) }
            .joined(separator: "\n")
    }

    private static func documentSummary(_ document: IconDocument, scope: IconScope) -> String {
        let layers = document.layers.map { $0.id }.joined(separator: ",")
        return "scope=\(scope.rawValue) documentId=\(document.id) title=\(document.title) size=\(Int(document.width))x\(Int(document.height)) layers=\(document.layers.count)[\(layers)] updatedAt=\(ISO8601DateFormatter().string(from: document.updatedAt))"
    }
}
