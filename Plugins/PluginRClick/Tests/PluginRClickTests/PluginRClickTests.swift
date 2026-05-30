import Testing
import Foundation
@testable import PluginRClick

@Test func packageLoads() async throws {
    #expect(RClickPlugin.id == "RClick")
}

@Test func appGroupConfigURLUsesSharedJSONFilename() {
    let containerURL = URL(fileURLWithPath: "/tmp/lumi-group", isDirectory: true)

    #expect(
        RClickConfigManager.sharedConfigURL(in: containerURL).path
            == "/tmp/lumi-group/RClickConfig.json"
    )
}
