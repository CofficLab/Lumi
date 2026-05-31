#if canImport(XCTest)
import XCTest
@testable import Lumi

final class AppSettingStoreTests: XCTestCase {
    func testReportsSaveResultAndReloadsSettings() throws {
        let settingsDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-app-settings-\(UUID().uuidString)", isDirectory: true)
        defer {
            AppSettingStore.resetTestingConfiguration()
            try? FileManager.default.removeItem(at: settingsDirectory)
        }

        AppSettingStore.configureForTesting(settingsDirectory: settingsDirectory)

        XCTAssertTrue(AppSettingStore.savePluginEnabled("PluginA", enabled: false))
        XCTAssertTrue(AppSettingStore.saveRemoteProviderModel(providerId: "provider", modelId: "model-a"))
        XCTAssertTrue(AppSettingStore.saveEditorRecentCommandIDs(["open", "search"]))

        AppSettingStore.resetTestingConfiguration()
        AppSettingStore.configureForTesting(settingsDirectory: settingsDirectory)

        XCTAssertEqual(AppSettingStore.loadPluginEnabled("PluginA"), false)
        XCTAssertEqual(AppSettingStore.loadRemoteProviderModel(providerId: "provider"), "model-a")
        XCTAssertEqual(AppSettingStore.loadEditorRecentCommandIDs(), ["open", "search"])
    }

    func testReportsSaveFailureWhenSettingsDirectoryIsBlocked() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-app-settings-blocked-\(UUID().uuidString)", isDirectory: true)
        let blockedDirectory = tempRoot.appendingPathComponent("AppSettings", isDirectory: true)
        defer {
            AppSettingStore.resetTestingConfiguration()
            try? FileManager.default.removeItem(at: tempRoot)
        }

        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        try "not a directory".write(to: blockedDirectory, atomically: true, encoding: .utf8)

        AppSettingStore.configureForTesting(settingsDirectory: blockedDirectory)

        XCTAssertFalse(AppSettingStore.savePluginEnabled("PluginA", enabled: true))
        XCTAssertNil(AppSettingStore.loadPluginEnabled("PluginA"))
    }

    func testQuarantinesCorruptSettingsAndRecoversOnSave() throws {
        let settingsDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-app-settings-corrupt-\(UUID().uuidString)", isDirectory: true)
        defer {
            AppSettingStore.resetTestingConfiguration()
            try? FileManager.default.removeItem(at: settingsDirectory)
        }

        try FileManager.default.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)
        let settingsURL = settingsDirectory.appendingPathComponent("app_settings.plist")
        let corruptURL = settingsDirectory.appendingPathComponent("app_settings.corrupt.plist")
        let invalidData = Data("not a plist".utf8)
        try invalidData.write(to: settingsURL)

        AppSettingStore.configureForTesting(settingsDirectory: settingsDirectory)

        XCTAssertTrue(AppSettingStore.savePluginEnabled("PluginA", enabled: false))
        XCTAssertEqual(try Data(contentsOf: corruptURL), invalidData)
        XCTAssertEqual(AppSettingStore.loadPluginEnabled("PluginA"), false)

        AppSettingStore.resetTestingConfiguration()
        AppSettingStore.configureForTesting(settingsDirectory: settingsDirectory)

        XCTAssertEqual(AppSettingStore.loadPluginEnabled("PluginA"), false)
    }
}
#endif
