#if canImport(XCTest)
import XCTest
@testable import Lumi

final class MacAgentRestorationTests: XCTestCase {
    @MainActor
    func testSavedApplicationStateURLUsesBundleIdentifier() {
        let libraryURL = URL(fileURLWithPath: "/tmp/lumi-library", isDirectory: true)

        let url = MacAgent.savedApplicationStateURL(
            bundleIdentifier: "com.coffic.lumi",
            libraryDirectory: libraryURL
        )

        XCTAssertEqual(
            url?.path,
            "/tmp/lumi-library/Saved Application State/com.coffic.lumi.savedState"
        )
    }

    @MainActor
    func testDisableSystemWindowRestorationClearsDefaultsAndSavedState() throws {
        let defaultsName = "MacAgentRestorationTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        defer { UserDefaults.standard.removePersistentDomain(forName: defaultsName) }

        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-restoration-\(UUID().uuidString)", isDirectory: true)
        let savedStateURL = try XCTUnwrap(MacAgent.savedApplicationStateURL(
            bundleIdentifier: "com.coffic.lumi",
            libraryDirectory: tempRoot
        ))
        try FileManager.default.createDirectory(at: savedStateURL, withIntermediateDirectories: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedStateURL.path))

        MacAgent.disableSystemWindowRestoration(
            defaults: defaults,
            bundleIdentifier: "com.coffic.lumi",
            libraryDirectory: tempRoot
        )

        XCTAssertFalse(defaults.bool(forKey: "NSQuitAlwaysKeepsWindows"))
        XCTAssertTrue(defaults.bool(forKey: "ApplePersistenceIgnoreState"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: savedStateURL.path))
    }

    @MainActor
    func testCoreWindowIDStoreReportsPersistenceResultAndRestoresRoutes() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-window-ids-\(UUID().uuidString)", isDirectory: true)
        defer {
            CoreWindowIDStore.resetTestingConfiguration()
            try? FileManager.default.removeItem(at: tempRoot)
        }

        CoreWindowIDStore.configureForTesting(storeDirectory: tempRoot)

        let first = UUID()
        let second = UUID()
        XCTAssertTrue(CoreWindowIDStore.saveWindowIds([first, second, first]))

        CoreWindowIDStore.resetTestingConfiguration()
        CoreWindowIDStore.configureForTesting(storeDirectory: tempRoot)

        XCTAssertEqual(CoreWindowIDStore.consumeNextWindowRoute().id, first)
        XCTAssertEqual(
            CoreWindowIDStore.consumeAdditionalWindowRoutes(excluding: [first]).map(\.id),
            [second]
        )
    }

    @MainActor
    func testCoreWindowIDStoreReportsPersistenceFailureWhenDirectoryIsBlocked() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-window-ids-blocked-\(UUID().uuidString)", isDirectory: true)
        let blockedDirectory = tempRoot.appendingPathComponent("WindowIDs", isDirectory: true)
        defer {
            CoreWindowIDStore.resetTestingConfiguration()
            try? FileManager.default.removeItem(at: tempRoot)
        }

        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        try "not a directory".write(to: blockedDirectory, atomically: true, encoding: .utf8)

        CoreWindowIDStore.configureForTesting(storeDirectory: blockedDirectory)

        XCTAssertFalse(CoreWindowIDStore.saveWindowIds([UUID()]))
    }
}
#endif
