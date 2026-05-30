import Foundation
import Testing
@testable import PluginAskUser

@Test func errorResultReturnsParseableJSON() throws {
    let result = AskUserTool.errorResult(message: "question is required")
    let parts = result.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)

    #expect(parts.first == "__ASK_USER_ERROR__")
    #expect(parts.count == 2)

    let data = try #require(parts.last?.data(using: .utf8))
    let response = try JSONDecoder().decode(AskUserErrorResponse.self, from: data)

    #expect(response.error == "question is required")
}
