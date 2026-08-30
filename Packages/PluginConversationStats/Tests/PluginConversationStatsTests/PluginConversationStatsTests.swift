import Testing
@testable import PluginConversationStats

@Test func tokenFormatting() async throws {
    #expect(1000.formattedTokensShort == "1K")
    #expect(1500.formattedTokensShort == "2K")
    #expect(128000.formattedContextSize == "128K")
    #expect(1000000.formattedContextSize == "1M")
}
