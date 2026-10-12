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

    @MainActor
    func testCorruptBindingsFileIsQuarantinedAndRecovered() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditorKeybindingStore-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let bindingsURL = directory.appendingPathComponent("editor_keybindings.json")
        let corruptURL = EditorKeybindingStore.corruptBindingsFileURL(for: bindingsURL)
        let invalidData = Data("not json".utf8)
        try invalidData.write(to: bindingsURL)

        let store = EditorKeybindingStore(bindingsFileURL: bindingsURL)

        XCTAssertTrue(store.customBindings.isEmpty)
        XCTAssertEqual(try Data(contentsOf: corruptURL), invalidData)
        XCTAssertTrue(store.setBinding(commandID: "builtin.find", key: "f", modifiers: [.command, .shift]))

        let reloadedStore = EditorKeybindingStore(bindingsFileURL: bindingsURL)
        XCTAssertEqual(reloadedStore.customBindings["builtin.find"]?.key, "f")
        XCTAssertEqual(reloadedStore.customBindings["builtin.find"]?.modifiers, [.command, .shift])
    }

    @MainActor
    func testSetBindingReportsFailureWhenSettingsDirectoryIsBlocked() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditorKeybindingStore-Blocked-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        let blockedDirectory = tempRoot.appendingPathComponent("settings")
        try "not a directory".write(to: blockedDirectory, atomically: true, encoding: .utf8)
        let bindingsURL = blockedDirectory.appendingPathComponent("editor_keybindings.json")

        let store = EditorKeybindingStore(bindingsFileURL: bindingsURL)

        XCTAssertFalse(store.setBinding(commandID: "builtin.find", key: "f", modifiers: [.command]))
    }
}
#endif
