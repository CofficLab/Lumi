import Testing
@testable import PluginFileLog

@Test func pluginMetadata() async throws {
    #expect(FileLogPlugin.id == "FileLog")
    #expect(FileLogPlugin.iconName == "doc.text.below.ecg")
    #expect(FileLogPlugin.order == 1)
}
