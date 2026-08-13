import Foundation
import KernelLumi

struct ListAppStoreConnectLocalizationsTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.list-localizations",
        displayName: "List App Store localizations",
        description: "List localizations for an App Store version."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "versionID": .object([
                    "type": .string("string"),
                    "description": .string("The App Store Connect appStoreVersion id.")
                ])
            ]),
            "required": .array([.string("versionID")])
        ])
    }

    func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        guard let versionID = arguments["versionID"]?.stringValue, !versionID.isEmpty else {
            return "Missing or empty versionID."
        }
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient(kernel: kernel)
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
