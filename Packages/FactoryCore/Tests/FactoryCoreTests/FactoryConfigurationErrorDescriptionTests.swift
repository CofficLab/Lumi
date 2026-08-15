import FactoryCore
import XCTest

final class FactoryConfigurationErrorDescriptionTests: XCTestCase {
    func testErrorDescriptionsAreNonEmpty() {
        let errors: [FactoryConfigurationError] = [
            .duplicatePluginID("dup.plugin"),
            .unknownEnabledPluginIDs(["b.plugin", "a.plugin"]),
            .unknownInitialContainerID("missing.container"),
        ]
        for error in errors {
            XCTAssertFalse(
                error.errorDescription?.isEmpty ?? true,
                "expected non-empty description for \(error)"
            )
        }

        XCTAssertEqual(
            (FactoryConfigurationError.unknownEnabledPluginIDs(["b.plugin", "a.plugin"]) as NSError).localizedDescription.contains("a.plugin"),
            true
        )
    }
}
