import FactoryCore
import XCTest
@testable import FactoryLumi

@MainActor
final class FactoryLumiFacadeTests: XCTestCase {
    func testDefaultConfigurationPointsAtChatPanel() {
        let configuration = FactoryLumi.configuration()
        XCTAssertEqual(configuration.initialContainerID, "com.coffic.lumi.plugin.chat-panel")
        XCTAssertEqual(configuration.plugins.count, LumiPluginCatalog.plugins.count)
        XCTAssertTrue(configuration.enabledPluginIDs.isEmpty)
        XCTAssertTrue(configuration.showsStatusBar)
        XCTAssertTrue(configuration.showsActivityBar)
    }

    func testIDSelectionRejectsEnabledIDsOutsideAllowlist() {
        let allowlist: Set<String> = ["com.coffic.lumi.plugin.storage"]
        XCTAssertThrowsError(
            try FactoryLumi.configuration(
                allowingIDs: allowlist,
                enabledPluginIDs: ["com.coffic.lumi.plugin.projects"]
            )
        ) { error in
            guard case FactoryConfigurationError.unknownEnabledPluginIDs = error else {
                return XCTFail("expected unknownEnabledPluginIDs, got \(error)")
            }
        }
    }

    func testWindowAndCommandConstructorsDoNotCrash() {
        _ = FactoryLumi.makeMainWindow()
        _ = FactoryLumi.makeSettingsWindow()
        _ = FactoryLumi.makeCommands()
    }
}
