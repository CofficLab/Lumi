#if canImport(XCTest)
import XCTest
@testable import EditorService

final class EditorConfigStoreTests: XCTestCase {
    func testSettingsDirectoryDoesNotDuplicateStorageDirectoryForDefaultRoot() {
        let appSupportURL = URL(fileURLWithPath: "/tmp/Application Support", isDirectory: true)

        let url = EditorConfigStore.settingsDirectoryURL(
            persistenceRootURL: nil,
            applicationSupportURL: appSupportURL,
            storageDirectoryName: "LumiEditor"
        )

        XCTAssertEqual(url.path, "/tmp/Application Support/LumiEditor/settings")
    }

    func testSettingsDirectoryUsesHostPersistenceRootWhenProvided() {
        let hostRootURL = URL(fileURLWithPath: "/tmp/HostRoot", isDirectory: true)
        let appSupportURL = URL(fileURLWithPath: "/tmp/Application Support", isDirectory: true)

        let url = EditorConfigStore.settingsDirectoryURL(
            persistenceRootURL: hostRootURL,
            applicationSupportURL: appSupportURL,
            storageDirectoryName: "LumiEditor"
        )

        XCTAssertEqual(url.path, "/tmp/HostRoot/LumiEditor/settings")
    }
}
#endif
