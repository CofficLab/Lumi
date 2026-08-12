import Foundation
import LumiKernel

struct ListAppStoreConnectAppsTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.list-apps",
        displayName: AppStoreConnectLocalization.string("List App Store apps"),
        description: AppStoreConnectLocalization.string("List apps from App Store Connect using the configured API key.")
    )

    var inputSchema: LumiJSONValue {
        .object([
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
        ])
    }

    func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let search = arguments["search"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawLimit = AppStoreConnectToolSupport.parseInt(arguments["limit"])
        let limit = min(max(rawLimit ?? 20, 1), 100)

        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient(kernel: kernel)
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
