import Foundation
import KernelCore
import KitAgentTool

/// Read or update the age-rating declaration for an App Store version.
///
/// Without any rating attributes the tool reads the current declaration.
/// When at least one rating attribute is provided the declaration is updated.
public struct SetAppStoreConnectAgeRatingTool: SuperAgentTool {
    public let name = "app_store_connect_set_age_rating"

    public init() {}

    // MARK: - Rating attribute keys accepted from the caller
    private static let ratingKeys: [String] = [
        "alcoholTobaccoOrDrugUseOrReferences",
        "contests",
        "gamblingSimulated",
        "horrorOrFearThemes",
        "medicalOrTreatmentInformation",
        "profanityOrCrudeHumor",
        "sexualContentGraphicAndNudity",
        "sexualContentOrNudity",
        "violenceCartoonOrFantasy",
        "violenceRealistic",
        "violenceRealisticProlongedGraphicOrSadistic",
    ]

    private static let boolRatingKeys: [String] = [
        "gambling",
        "seventeenPlus",
        "unrestrictedWebAccess",
    ]

    private static let kidsAgeBandKey = "kidsAgeBand"

    public func description(for language: LanguagePreference) -> String {
        AppStoreConnectLocalization.string(
            "Read or update the age-rating declaration for an App Store version. "
            + "Pass no rating attributes to read the current declaration. "
            + "Pass at least one rating attribute to update. "
            + "String ratings accept NONE, INFREQUENT_OR_MILD, or FREQUENT_OR_INTENSE. "
            + "kidsAgeBand accepts FIVE_AND_UNDER, SIX_TO_EIGHT, or NINE_TO_ELEVEN. "
            + "IMPORTANT: The App Store Connect API cannot create a new age-rating declaration — "
            + "it can only read or update existing ones. For versions created via API, "
            + "the declaration must first be initialized through the App Store Connect website "
            + "(app → version → Age Rating → complete questionnaire → Save)."
        )
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        AppStoreConnectLocalization.string("Set age rating")
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties: [String: AppStoreConnectToolSchemaValue] = [
            "versionID": .object([
                "type": .string("string"),
                "description": .string(AppStoreConnectLocalization.string("The appStoreVersion id."))
            ]),
        ]

        let levelDesc = AppStoreConnectLocalization.string("NONE, INFREQUENT_OR_MILD, or FREQUENT_OR_INTENSE")
        for key in Self.ratingKeys {
            properties[key] = .object([
                "type": .string("string"),
                "description": .string(levelDesc)
            ])
        }
        for key in Self.boolRatingKeys {
            properties[key] = .object([
                "type": .string("boolean"),
            ])
        }
        properties[Self.kidsAgeBandKey] = .object([
            "type": .string("string"),
            "description": .string(AppStoreConnectLocalization.string("FIVE_AND_UNDER, SIX_TO_EIGHT, or NINE_TO_ELEVEN"))
        ])

        return AppStoreConnectToolSchemaValue.object([
            "type": .string("object"),
            "properties": .object(properties),
            "required": .array([.string("versionID")])
        ]).dictionaryValue
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let versionID = arguments["versionID"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !versionID.isEmpty else {
            return "Missing or empty versionID."
        }

        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }

        // Collect update attributes (if any)
        var updateAttributes: [String: Any] = [:]
        for key in Self.ratingKeys {
            if let value = arguments[key]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                updateAttributes[key] = value
            }
        }
        for key in Self.boolRatingKeys {
            if let value = AppStoreConnectToolSupport.parseBool(arguments[key]) {
                updateAttributes[key] = value
            }
        }
        if let kids = arguments[Self.kidsAgeBandKey]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
           !kids.isEmpty {
            updateAttributes[Self.kidsAgeBandKey] = kids
        }

        do {
            // Read mode
            if updateAttributes.isEmpty {
                if let declaration = try await client.readAgeRatingDeclaration(versionID: versionID) {
                    return formatDeclaration(declaration)
                }
                if let declaration = try await client.readAgeRatingDeclarationByAppInfo(versionID: versionID) {
                    return "(app-info level) " + formatDeclaration(declaration)
                }
                return [
                    "No age-rating declaration found for version id=\(versionID).",
                    "The App Store Connect API does not support creating age-rating declarations.",
                    "You must create one through the App Store Connect website:",
                    "  https://appstoreconnect.apple.com/apps/\(versionID)/distribution",
                    "Open the version → Age Rating section → complete the questionnaire → Save.",
                    "After that, use this tool to read or update the declaration."
                ].joined(separator: "\n")
            }

            // Update mode: try version-level first, then fallback to appInfo-level
            var existing = try await client.readAgeRatingDeclaration(versionID: versionID)
            var source = "version"
            if existing == nil {
                existing = try await client.readAgeRatingDeclarationByAppInfo(versionID: versionID)
                source = "appInfo"
            }
            guard let target = existing else {
                return [
                    "No age-rating declaration found for version id=\(versionID).",
                    "The App Store Connect API does not support creating age-rating declarations — it can only update existing ones.",
                    "Create one first through the App Store Connect website:",
                    "  https://appstoreconnect.apple.com",
                    "Navigate to your app → the version → Age Rating → complete the questionnaire → Save.",
                    "Then retry this tool to update the declaration programmatically."
                ].joined(separator: "\n")
            }
            let updated = try await client.updateAgeRating(
                declarationID: target.id,
                attributes: updateAttributes
            )
            return "Age rating updated via \(source) for version id=\(versionID).\n" + formatDeclaration(updated)
        } catch {
            return "Failed to manage age rating: \(error.localizedDescription)"
        }
    }

    private func formatDeclaration(_ d: AgeRatingDeclaration) -> String {
        var lines = ["Age rating declaration id=\(d.id):"]
        lines.append("  alcoholTobaccoOrDrugUseOrReferences=\(d.alcoholTobaccoOrDrugUseOrReferences ?? "(nil)")")
        lines.append("  contests=\(d.contests ?? "(nil)")")
        lines.append("  gambling=\(d.gambling.map { "\($0)" } ?? "(nil)")")
        lines.append("  gamblingSimulated=\(d.gamblingSimulated ?? "(nil)")")
        lines.append("  horrorOrFearThemes=\(d.horrorOrFearThemes ?? "(nil)")")
        lines.append("  kidsAgeBand=\(d.kidsAgeBand ?? "(nil)")")
        lines.append("  medicalOrTreatmentInformation=\(d.medicalOrTreatmentInformation ?? "(nil)")")
        lines.append("  profanityOrCrudeHumor=\(d.profanityOrCrudeHumor ?? "(nil)")")
        lines.append("  seventeenPlus=\(d.seventeenPlus.map { "\($0)" } ?? "(nil)")")
        lines.append("  sexualContentGraphicAndNudity=\(d.sexualContentGraphicAndNudity ?? "(nil)")")
        lines.append("  sexualContentOrNudity=\(d.sexualContentOrNudity ?? "(nil)")")
        lines.append("  unrestrictedWebAccess=\(d.unrestrictedWebAccess.map { "\($0)" } ?? "(nil)")")
        lines.append("  violenceCartoonOrFantasy=\(d.violenceCartoonOrFantasy ?? "(nil)")")
        lines.append("  violenceRealistic=\(d.violenceRealistic ?? "(nil)")")
        lines.append("  violenceRealisticProlongedGraphicOrSadistic=\(d.violenceRealisticProlongedGraphicOrSadistic ?? "(nil)")")
        return lines.joined(separator: "\n")
    }
}
