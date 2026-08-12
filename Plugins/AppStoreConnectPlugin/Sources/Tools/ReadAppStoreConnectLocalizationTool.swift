import Foundation
import LumiKernel

/// Read-only companion to `UpdateAppStoreConnectLocalizationTool`. Required so
/// agents can safely plan a partial edit (diff, length check, escape-only
/// rewrites like replacing literal `\n` with real newlines) without forcing the
/// user to paste the entire current `description` / `keywords` back into chat.
struct ReadAppStoreConnectLocalizationTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.read-localization",
        displayName: "Read localization metadata",
        description: "Read the full current metadata of a single App Store version localization. Returns the verbatim contents of promotionalText, description, keywords, whatsNew, supportURL and marketingURL. Read-only — use this before update-localization to plan a safe edit."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "localizationID": .object([
                    "type": .string("string"),
                    "description": .string("The appStoreVersionLocalization id (see id field from list-localizations).")
                ])
            ]),
            "required": .array([.string("localizationID")])
        ])
    }

    func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel {
        .low
    }

    func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        guard let localizationID = arguments["localizationID"]?.stringValue,
              !localizationID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Missing or empty localizationID. Pass a valid appStoreVersionLocalization identifier from list-localizations."
        }

        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient(kernel: kernel)
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }

        do {
            let localization = try await client.readLocalization(id: localizationID)
            return AppStoreVersionLocalizationFormatter.detailString(localization)
        } catch {
            return "Failed to read localization: \(error.localizedDescription)"
        }
    }
}

/// Shared pretty-printer used by `ReadAppStoreConnectLocalizationTool` and
/// `ListAppStoreConnectLocalizationsTool` so the field layout stays consistent.
enum AppStoreVersionLocalizationFormatter {
    static func detailString(_ localization: AppStoreVersionLocalization) -> String {
        """
        Localization detail:
        - id=\(localization.id)
        - locale=\(localization.locale)
        - promotionalText=\(quote(localization.promotionalText))
        - description=\(quote(localization.description))
        - keywords=\(quote(localization.keywords))
        - whatsNew=\(quote(localization.whatsNew))
        - supportURL=\(localization.supportURL.isEmpty ? "(empty)" : localization.supportURL)
        - marketingURL=\(localization.marketingURL.isEmpty ? "(empty)" : localization.marketingURL)
        """
    }

    /// Renders a multi-line string the way an agent-friendly tool result should:
    /// the literal contents surrounded by a tagged fence so trailing newlines and
    /// blank lines are preserved instead of being collapsed by chat rendering.
    private static func quote(_ value: String) -> String {
        if value.isEmpty { return "(empty)" }
        return "<<<\(value)>>>"
    }
}
