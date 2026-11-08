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
        "gunsOrOtherWeapons",
        "horrorOrFearThemes",
        "matureOrSuggestiveThemes",
        "medicalOrTreatmentInformation",
        "profanityOrCrudeHumor",
        "sexualContentGraphicAndNudity",
        "sexualContentOrNudity",
        "violenceCartoonOrFantasy",
        "violenceRealistic",
        "violenceRealisticProlongedGraphicOrSadistic",
        "ageRatingOverride",
        "ageRatingOverrideV2",
        "koreaAgeRatingOverride",
    ]

    /// Override fields use a different value set than the content-descriptor fields.
    private static let ratingKeyDescriptions: [String: String] = [
        "ageRatingOverride": "NONE, NINE_PLUS, THIRTEEN_PLUS, SIXTEEN_PLUS, EIGHTEEN_PLUS, or UNRATED",
        "ageRatingOverrideV2": "NONE, NINE_PLUS, THIRTEEN_PLUS, SIXTEEN_PLUS, EIGHTEEN_PLUS, or UNRATED",
        "koreaAgeRatingOverride": "NONE, FIFTEEN_PLUS, or NINETEEN_PLUS",
    ]

    private static let boolRatingKeys: [String] = [
        "advertising",
        "ageAssurance",
        "gambling",
        "healthOrWellnessTopics",
        "lootBox",
        "messagingAndChat",
        "parentalControls",
        "seventeenPlus",
        "socialMedia",
        "socialMediaAgeRestricted",
        "unrestrictedWebAccess",
        "userGeneratedContent",
    ]

    private static let kidsAgeBandKey = "kidsAgeBand"

    public func description(for language: LanguagePreference) -> String {
        AppStoreConnectLocalization.string(
            "Read or update the age-rating declaration for an App Store version. "
            + "Pass no rating attributes to read the current declaration. "
            + "Pass at least one rating attribute to update. "
            + "String ratings accept NONE, INFREQUENT, or FREQUENT "
            + "(legacy INFREQUENT_OR_MILD / FREQUENT_OR_INTENSE also accepted). "
            + "kidsAgeBand accepts FIVE_AND_UNDER, SIX_TO_EIGHT, or NINE_TO_ELEVEN. "
            + "Boolean attributes such as socialMedia, advertising, lootBox, and messagingAndChat accept true or false. "
            + "socialMedia must be set before a review submission can be accepted. "
            + "The declaration is app-level and shared by all versions. "
            + "IMPORTANT: The App Store Connect API cannot create a new age-rating declaration — "
            + "it can only read or update existing ones. Complete the questionnaire once per app "
            + "through the App Store Connect website (App Information → Age Ratings → Save), "
            + "then this tool can read and update it for every version."
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
                "description": .string(Self.ratingKeyDescriptions[key] ?? levelDesc)
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
            throw ToolExecutionError.executionFailed(toolName: name, reason: "Missing or empty versionID.")
        }

        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { throw ToolExecutionError.executionFailed(toolName: name, reason: errorMessage ?? "Failed to initialize App Store Connect client.") }

        // Collect update attributes (if any)
        let updateAttributes = Self.updateAttributes(from: arguments)

        do {
            // Read mode
            if updateAttributes.isEmpty {
                if let declaration = try await client.readAgeRatingDeclaration(versionID: versionID) {
                    return formatDeclaration(declaration)
                }
                return [
                    "No age-rating declaration found for app of version id=\(versionID).",
                    "The App Store Connect API does not support creating age-rating declarations.",
                    "Complete the questionnaire once for this app through the App Store Connect website:",
                    "  https://appstoreconnect.apple.com",
                    "My Apps → your app → App Information → Age Ratings → Set Up Age Ratings → Save.",
                    "The declaration is app-level and applies to all versions of the app; after that,",
                    "use this tool to read or update it programmatically."
                ].joined(separator: "\n")
            }

            // Update mode: the declaration is app-level (appInfo), shared by all versions.
            guard let target = try await client.readAgeRatingDeclaration(versionID: versionID) else {
                return [
                    "No age-rating declaration found for app of version id=\(versionID).",
                    "The App Store Connect API does not support creating age-rating declarations — it can only update existing ones.",
                    "Complete the questionnaire once for this app through the App Store Connect website:",
                    "  https://appstoreconnect.apple.com",
                    "My Apps → your app → App Information → Age Ratings → Set Up Age Ratings → Save.",
                    "The declaration is app-level and applies to all versions of the app; then retry this tool."
                ].joined(separator: "\n")
            }
            let updated = try await client.updateAgeRating(
                declarationID: target.id,
                attributes: updateAttributes
            )
            return "Age rating updated for version id=\(versionID).\n" + formatDeclaration(updated)
        } catch {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "Failed to manage age rating: \(error.localizedDescription)")
        }
    }

    /// 把工具参数转换为 `ageRatingDeclarations` 的 PATCH 属性。
    ///
    /// 空字符串与非布尔值会被忽略，未提供的字段不会出现在结果里；
    /// 布尔字段显式传 `false` 时同样会写入（例如 `socialMedia: false`）。
    static func updateAttributes(from arguments: [String: ToolArgument]) -> [String: Any] {
        var attributes: [String: Any] = [:]
        for key in Self.ratingKeys {
            if let value = arguments[key]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                attributes[key] = value
            }
        }
        for key in Self.boolRatingKeys {
            if let value = AppStoreConnectToolSupport.parseBool(arguments[key]) {
                attributes[key] = value
            }
        }
        if let kids = arguments[Self.kidsAgeBandKey]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
           !kids.isEmpty {
            attributes[Self.kidsAgeBandKey] = kids
        }
        return attributes
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
        lines.append("  gunsOrOtherWeapons=\(d.gunsOrOtherWeapons ?? "(nil)")")
        lines.append("  matureOrSuggestiveThemes=\(d.matureOrSuggestiveThemes ?? "(nil)")")
        lines.append("  ageRatingOverride=\(d.ageRatingOverride ?? "(nil)")")
        lines.append("  ageRatingOverrideV2=\(d.ageRatingOverrideV2 ?? "(nil)")")
        lines.append("  koreaAgeRatingOverride=\(d.koreaAgeRatingOverride ?? "(nil)")")
        lines.append("  advertising=\(d.advertising.map { "\($0)" } ?? "(nil)")")
        lines.append("  ageAssurance=\(d.ageAssurance.map { "\($0)" } ?? "(nil)")")
        lines.append("  healthOrWellnessTopics=\(d.healthOrWellnessTopics.map { "\($0)" } ?? "(nil)")")
        lines.append("  lootBox=\(d.lootBox.map { "\($0)" } ?? "(nil)")")
        lines.append("  messagingAndChat=\(d.messagingAndChat.map { "\($0)" } ?? "(nil)")")
        lines.append("  parentalControls=\(d.parentalControls.map { "\($0)" } ?? "(nil)")")
        lines.append("  socialMedia=\(d.socialMedia.map { "\($0)" } ?? "(nil)")")
        lines.append("  socialMediaAgeRestricted=\(d.socialMediaAgeRestricted.map { "\($0)" } ?? "(nil)")")
        lines.append("  userGeneratedContent=\(d.userGeneratedContent.map { "\($0)" } ?? "(nil)")")
        return lines.joined(separator: "\n")
    }
}
