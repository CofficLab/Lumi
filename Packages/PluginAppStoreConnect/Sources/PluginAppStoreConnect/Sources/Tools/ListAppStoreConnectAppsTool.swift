import Foundation
import KernelCore
import KitAgentTool

public struct ListAppStoreConnectAppsTool: SuperAgentTool {
    public let name = "app_store_connect_list_apps"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        AppStoreConnectLocalization.string("List apps from App Store Connect using the configured API key.")
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        AppStoreConnectLocalization.string("List App Store apps")
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        AppStoreConnectToolSchemaValue.object([
            "type": .string("object"),
            "properties": .object([
                "search": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("Optional case-insensitive search query to filter apps by name."))
                ]),
                "limit": .object([
                    "type": .string("integer"),
                    "description": .string(AppStoreConnectLocalization.string("Maximum number of apps to return (default 20, max 100)."))
                ])
            ])
        ]).dictionaryValue
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let search = arguments["search"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawLimit = AppStoreConnectToolSupport.parseInt(arguments["limit"])
        let limit = min(max(rawLimit ?? 20, 1), 100)

        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }

        do {
            let apps = try await client.listApps(search: search, limit: limit)
            if apps.isEmpty {
                return "No apps were found for the current App Store Connect account."
            }

            let header = "App Store Connect apps (showing \(apps.count)):"
            let lines = apps.map { app in
                let platform = app.platform
                return "- \(app.name) (\(app.bundleID)) [\(platform)] id=\(app.id)"
            }
            return ([header] + lines).joined(separator: "\n")
        } catch {
            return "Failed to list apps: \(error.localizedDescription)"
        }
    }
}
