import Testing
@testable import PluginChatSubmit

@Test func metadataIsStable() async throws {
    #expect(await ChatSubmitPlugin.id == "ChatSubmit")
}
