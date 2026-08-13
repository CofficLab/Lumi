import Foundation
import KernelLumi

/// 列出插件管理的图标文档，跨 project / app 两个作用域。
public struct ListIconDocumentsTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "list_icon_documents",
        displayName: "List Icon Documents",
        description: "List plugin-managed app icon documents across project and app scopes."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        [
            "type": "object",
            "properties": [
                "scope": [
                    "type": "string",
                    "enum": .array(["all"] + IconScope.allCases.map { .string($0.rawValue) }),
                    "description": "Filter by scope: 'project', 'app', or 'all' (default).",
                ],
            ],
        ]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "List icon documents"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        let scopeFilter = (arguments.string("scope") ?? "all").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let snapshot = await MainActor.run { () -> [(IconScope, [IconDocument])] in
            // 列表以磁盘为准，确保 Agent 看到最新内容（包括尚未载入内存的文档）。
            var result: [(IconScope, [IconDocument])] = []
            let store = IconDocumentStore.shared
            if scopeFilter == "all" || scopeFilter == IconScope.project.rawValue {
                let docs = IconDocumentFileStore.loadAll(storagePath: store.projectStoragePath)
                result.append((.project, docs))
            }
            if scopeFilter == "all" || scopeFilter == IconScope.app.rawValue {
                let docs = IconDocumentFileStore.loadAll(storagePath: store.appStoragePath)
                result.append((.app, docs))
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
