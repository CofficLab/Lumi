#if canImport(XCTest)
import XCTest
@testable import EditorService

final class EditorKeybindingStoreTests: XCTestCase {
    func testBindingsFileUsesDefaultRootWithoutForceUnwrappingApplicationSupport() {
        let appSupportURL = URL(fileURLWithPath: "/tmp/Application Support", isDirectory: true)

        let url = EditorKeybindingStore.bindingsFileURL(
            persistenceRootURL: nil,
            applicationSupportURL: appSupportURL,
            storageDirectoryName: "LumiEditor"
        )

        XCTAssertEqual(url.path, "/tmp/Application Support/LumiEditor/settings/editor_keybindings.json")
    }

    func testBindingsFileUsesHostPersistenceRootWhenProvided() {
        let hostRootURL = URL(fileURLWithPath: "/tmp/HostRoot", isDirectory: true)
        let appSupportURL = URL(fileURLWithPath: "/tmp/Application Support", isDirectory: true)

        let url = EditorKeybindingStore.bindingsFileURL(
            persistenceRootURL: hostRootURL,
            applicationSupportURL: appSupportURL,
            storageDirectoryName: "LumiEditor"
        )

        XCTAssertEqual(url.path, "/tmp/HostRoot/LumiEditor/settings/editor_keybindings.json")
    }
}
#endif
