import Testing
import Foundation
@testable import KitAgentTool

final class CodableCoverageTests {
    @Test("displayName returns localized names for every case")
    func displayNameCoversAllCases() {
        for preference in LanguagePreference.allCases {
            #expect(!preference.displayName.isEmpty)
        }
    }

    @Test("interaction state answer is nil while waiting")
    func answerIsNilWhileWaiting() {
        #expect(ToolCallInteractionState.waiting.answer == nil)
    }

    @Test("ToolCall encodes optional display description when present")
    func encodeDisplayDescription() throws {
        let call = ToolCall(
            id: "1",
            name: "demo",
            arguments: "{}",
            displayDescription: "A demo call"
        )
        let data = try JSONEncoder().encode(call)
        let decoded = try JSONDecoder().decode(ToolCall.self, from: data)
        #expect(decoded.displayDescription == "A demo call")
    }

    @Test("ToolCall omits display description when absent")
    func omitDisplayDescription() throws {
        let call = ToolCall(id: "1", name: "demo", arguments: "{}")
        let data = try JSONEncoder().encode(call)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["displayDescription"] == nil)
    }
}
