@testable import PluginAppStoreConnect
import Foundation
import KitAgentTool
import Testing

@Suite("SetAppStoreConnectAgeRatingTool")
struct SetAppStoreConnectAgeRatingToolTests {
    private func properties(for tool: SetAppStoreConnectAgeRatingTool = SetAppStoreConnectAgeRatingTool()) -> [String: Any] {
        tool.inputSchema(for: .english)["properties"] as? [String: Any] ?? [:]
    }

    @Test("schema exposes the previously missing age-rating attributes")
    func schemaExposesMissingAttributes() throws {
        let properties = properties()

        for key in [
            "socialMedia", "advertising", "healthOrWellnessTopics", "lootBox",
            "messagingAndChat", "parentalControls", "ageAssurance",
            "socialMediaAgeRestricted", "userGeneratedContent",
        ] {
            let property = try #require(properties[key] as? [String: Any])
            #expect(property["type"] as? String == "boolean")
        }

        for key in [
            "gunsOrOtherWeapons", "matureOrSuggestiveThemes",
            "ageRatingOverride", "ageRatingOverrideV2", "koreaAgeRatingOverride",
        ] {
            let property = try #require(properties[key] as? [String: Any])
            #expect(property["type"] as? String == "string")
        }
    }

    @Test("explicit false is sent instead of being dropped")
    func explicitFalseIsSent() {
        let attributes = SetAppStoreConnectAgeRatingTool.updateAttributes(from: [
            "versionID": ToolArgument("version-1"),
            "socialMedia": ToolArgument("false"),
            "lootBox": ToolArgument(false),
            "messagingAndChat": ToolArgument("true"),
        ])

        #expect(attributes["socialMedia"] as? Bool == false)
        #expect(attributes["lootBox"] as? Bool == false)
        #expect(attributes["messagingAndChat"] as? Bool == true)
    }

    @Test("absent attributes stay out of the PATCH payload")
    func absentAttributesAreOmitted() {
        let attributes = SetAppStoreConnectAgeRatingTool.updateAttributes(from: [
            "versionID": ToolArgument("version-1"),
            "socialMedia": ToolArgument("false"),
        ])

        #expect(Set(attributes.keys) == ["socialMedia"])
    }

    @Test("Apple payload decodes the new attributes")
    func decodesNewAttributes() throws {
        let json = """
        {
          "id": "declaration-1",
          "attributes": {
            "socialMedia": false,
            "advertising": true,
            "healthOrWellnessTopics": false,
            "lootBox": true,
            "messagingAndChat": false,
            "parentalControls": true,
            "ageAssurance": false,
            "socialMediaAgeRestricted": true,
            "userGeneratedContent": false,
            "gunsOrOtherWeapons": "NONE",
            "matureOrSuggestiveThemes": "INFREQUENT_OR_MILD",
            "ageRatingOverride": "NONE",
            "ageRatingOverrideV2": "NINE_PLUS",
            "koreaAgeRatingOverride": "NONE"
          }
        }
        """
        let declaration = try JSONDecoder().decode(
            AgeRatingDeclaration.self,
            from: Data(json.utf8)
        )

        #expect(declaration.socialMedia == false)
        #expect(declaration.advertising == true)
        #expect(declaration.lootBox == true)
        #expect(declaration.gunsOrOtherWeapons == "NONE")
        #expect(declaration.ageRatingOverrideV2 == "NINE_PLUS")
        #expect(declaration.koreaAgeRatingOverride == "NONE")
    }
}
