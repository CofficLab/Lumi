import Foundation
import KernelCore
import KitAgentTool

public struct ListAppStoreConnectLocalizationsTool: SuperAgentTool {
    public let name = "app_store_connect_list_localizations"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "List localizations for an App Store version."
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "List App Store localizations"
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        AppStoreConnectToolSchemaValue.object([
            "type": .string("object"),
            "properties": .object([
                "versionID": .object([
                    "type": .string("string"),
                    "description": .string("The App Store Connect appStoreVersion id.")
                ])
            ]),
            "required": .array([.string("versionID")])
        ]).dictionaryValue
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let versionID = arguments["versionID"]?.stringValue, !versionID.isEmpty else {
            return "Missing or empty versionID."
        }
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }
        do {
            let localizations = try await client.listLocalizations(versionID: versionID)
            guard !localizations.isEmpty else { return "No localizations found for version id=\(versionID)." }
            let header = "Localizations for version id=\(versionID) — use id with read-localization / update-localization:"
            // Show every editable field so the agent never has to do a follow-up
            // read just to discover whether a field is empty.
            let lines = localizations.map { localization -> String in
                """
                - \(localization.locale)
                  id=\(localization.id)
                  description=\(summarize(localization.description))
                  keywords=\(summarize(localization.keywords))
                  whatsNew=\(summarize(localization.whatsNew))
                  promotionalText=\(summarize(localization.promotionalText))
                  supportURL=\(localization.supportURL.isEmpty ? "(empty)" : localization.supportURL)
                  marketingURL=\(localization.marketingURL.isEmpty ? "(empty)" : localization.marketingURL)
                """
            }
            return ([header] + lines).joined(separator: "\n")
        } catch {
            return "Failed to list localizations: \(error.localizedDescription)"
        }
    }

    /// Collapses a multi-line string into a one-line preview for list output.
    /// Long values are truncated to keep the list readable; full content is
    /// always available via `read-localization`.
    private func summarize(_ value: String) -> String {
        if value.isEmpty { return "(empty)" }
        let collapsed = value.replacingOccurrences(of: "\n", with: "\\n")
        if collapsed.count <= 80 { return collapsed }
        let endIndex = collapsed.index(collapsed.startIndex, offsetBy: 80)
        return collapsed[..<endIndex] + "…(\(collapsed.count) chars)"
    }
}
