import XCTest
@testable import FactoryBookletMaker

@MainActor
final class FactoryBookletMakerFacadeTests: XCTestCase {
    func testConfigurationBuildsFromFixedCatalog() {
        let configuration = FactoryBookletMaker.configuration
        XCTAssertEqual(configuration.enabledPluginIDs, [BookletMakerPluginCatalog.bookletMakerPluginID])
        XCTAssertEqual(configuration.initialContainerID, BookletMakerPluginCatalog.bookletMakerPluginID)
        XCTAssertFalse(configuration.showsStatusBar)
        XCTAssertFalse(configuration.showsActivityBar)
    }

    func testWindowAndViewConstructorsDoNotCrash() {
        _ = FactoryBookletMaker.makeMainWindow()
        _ = FactoryBookletMaker.makeSettingsWindow()
        _ = FactoryBookletMaker.makeCommands()
    }
}
