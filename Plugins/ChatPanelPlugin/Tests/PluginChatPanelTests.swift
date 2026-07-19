import Foundation
import Testing
@testable import ChatPanelPlugin
import XCTest
import Combine

// MARK: - Test Helpers

/// ChatPanel测试辅助类
final class ChatPanelTestHelper {
    static func createTemporaryDirectory() throws -> URL {
        let uuid = UUID().uuidString
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChatPanelTests")
            .appendingPathComponent(uuid, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    static func cleanupTemporaryDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    static func createCorruptPlist(at url: URL) throws {
        let corruptData = Data([0x00, 0x01, 0x02, 0x03])
        try corruptData.write(to: url)
    }
}

/// Mock文件管理器用于测试
final class MockFileManager: FileManager {
    var fileExistsResults: [String: Bool] = [:]
    var removeItemCalled: [String] = []
    var moveItemCalled: [(from: String, to: String)] = []
    var createDirectoryCalled: [String] = []

    override func fileExists(atPath path: String) -> Bool {
        return fileExistsResults[path] ?? super.fileExists(atPath: path)
    }

    override func removeItem(at url: URL) throws {
        removeItemCalled.append(url.path)
        try? super.removeItem(at: url)
    }

    override func moveItem(at srcURL: URL, to dstURL: URL) throws {
        moveItemCalled.append((from: srcURL.path, to: dstURL.path))
        try? super.moveItem(at: srcURL, to: dstURL)
    }

    override func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey: Any]? = nil) throws {
        createDirectoryCalled.append(url.path)
        try? super.createDirectory(at: url, withIntermediateDirectories: createIntermediates, attributes: attributes)
    }
}

@Test func localStorePersistsConversationListWidth() throws {
    let databaseDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LocalStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: databaseDirectory) }

    let store = LocalStore(databaseDirectory: databaseDirectory)
    store.saveConversationListWidth(312)

    let reloadedStore = LocalStore(databaseDirectory: databaseDirectory)
    #expect(reloadedStore.loadConversationListWidth() == 312)

    let settingsURL = databaseDirectory
        .appendingPathComponent("ChatPanelPlugin", isDirectory: true)
        .appendingPathComponent("settings.plist")
    #expect(FileManager.default.fileExists(atPath: settingsURL.path))
}

@Test func preferredConversationListWidthAllowsWidePanels() throws {
    let databaseDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LocalStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: databaseDirectory) }

    let store = LocalStore(databaseDirectory: databaseDirectory)
    store.saveConversationListWidth(780)

    #expect(SplitWidth.preferredWidth(databaseDirectory: databaseDirectory) == 780)
}

@Test func preferredConversationListWidthClampsOversizedValues() throws {
    let databaseDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LocalStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: databaseDirectory) }

    let store = LocalStore(databaseDirectory: databaseDirectory)
    store.saveConversationListWidth(1_200)

    #expect(SplitWidth.preferredWidth(databaseDirectory: databaseDirectory) == SplitWidth.defaultMaximumWidth)
}

// MARK: - LocalStore Tests

@Test func localStoreInitializationCreatesDirectory() throws {
    let databaseDirectory = try ChatPanelTestHelper.createTemporaryDirectory()
    defer { ChatPanelTestHelper.cleanupTemporaryDirectory(databaseDirectory) }

    let pluginDirectory = databaseDirectory.appendingPathComponent("ChatPanelPlugin", isDirectory: true)

    #expect(!FileManager.default.fileExists(atPath: pluginDirectory.path))

    _ = LocalStore(databaseDirectory: databaseDirectory)

    #expect(FileManager.default.fileExists(atPath: pluginDirectory.path))
}

@Test func localStoreConversationListWidthPersistence() throws {
    let databaseDirectory = try ChatPanelTestHelper.createTemporaryDirectory()
    defer { ChatPanelTestHelper.cleanupTemporaryDirectory(databaseDirectory) }

    let store = LocalStore(databaseDirectory: databaseDirectory)

    // Test initial value
    #expect(store.loadConversationListWidth() == 0.0)

    // Test saving and loading
    store.saveConversationListWidth(350.0)
    #expect(store.loadConversationListWidth() == 350.0)

    // Test overwriting
    store.saveConversationListWidth(400.0)
    #expect(store.loadConversationListWidth() == 400.0)
}

@Test func localStoreSelectedConversationIDPersistence() throws {
    let databaseDirectory = try ChatPanelTestHelper.createTemporaryDirectory()
    defer { ChatPanelTestHelper.cleanupTemporaryDirectory(databaseDirectory) }

    let store = LocalStore(databaseDirectory: databaseDirectory)

    // Test initial value
    #expect(store.loadSelectedConversationID() == nil)

    // Test saving and loading valid UUID
    let testUUID = UUID()
    store.saveSelectedConversationID(testUUID)
    #expect(store.loadSelectedConversationID() == testUUID)

    // Test saving nil
    store.saveSelectedConversationID(nil)
    #expect(store.loadSelectedConversationID() == nil)
}

@Test func localStoreHandlesInvalidUUIDGracefully() throws {
    let databaseDirectory = try ChatPanelTestHelper.createTemporaryDirectory()
    defer { ChatPanelTestHelper.cleanupTemporaryDirectory(databaseDirectory) }

    let store = LocalStore(databaseDirectory: databaseDirectory)

    // Create settings file with invalid UUID string
    let settingsURL = databaseDirectory
        .appendingPathComponent("ChatPanelPlugin", isDirectory: true)
        .appendingPathComponent("settings.plist")

    try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)

    let invalidData = ["selected_conversation_id": "not-a-valid-uuid"] as [String: Any]
    let plistData = try PropertyListSerialization.data(fromPropertyList: invalidData, format: .xml, options: 0)
    try plistData.write(to: settingsURL)

    // Should return nil for invalid UUID
    #expect(store.loadSelectedConversationID() == nil)
}

@Test func localStoreHandlesCorruptSettingsFile() throws {
    let databaseDirectory = try ChatPanelTestHelper.createTemporaryDirectory()
    defer { ChatPanelTestHelper.cleanupTemporaryDirectory(databaseDirectory) }

    let pluginDirectory = databaseDirectory.appendingPathComponent("ChatPanelPlugin", isDirectory: true)
    try FileManager.default.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)

    let settingsURL = pluginDirectory.appendingPathComponent("settings.plist")
    let corruptSettingsURL = pluginDirectory.appendingPathComponent("settings.corrupt.plist")

    // Create corrupt settings file
    try ChatPanelTestHelper.createCorruptPlist(at: settingsURL)

    let store = LocalStore(databaseDirectory: databaseDirectory)

    // Should return safe defaults despite corrupt file
    #expect(store.loadConversationListWidth() == 0.0)
    #expect(store.loadSelectedConversationID() == nil)

    // Corrupt file should be quarantined
    #expect(!FileManager.default.fileExists(atPath: settingsURL.path))
    #expect(FileManager.default.fileExists(atPath: corruptSettingsURL.path))
}

@Test func localStoreHandlesMissingSettingsFile() throws {
    let databaseDirectory = try ChatPanelTestHelper.createTemporaryDirectory()
    defer { ChatPanelTestHelper.cleanupTemporaryDirectory(databaseDirectory) }

    let store = LocalStore(databaseDirectory: databaseDirectory)

    // Should handle missing file gracefully
    #expect(store.loadConversationListWidth() == 0.0)
    #expect(store.loadSelectedConversationID() == nil)
}

@Test func localStoreSetNilRemovesValue() throws {
    let databaseDirectory = try ChatPanelTestHelper.createTemporaryDirectory()
    defer { ChatPanelTestHelper.cleanupTemporaryDirectory(databaseDirectory) }

    let store = LocalStore(databaseDirectory: databaseDirectory)

    // Set a value
    store.saveConversationListWidth(300.0)
    #expect(store.loadConversationListWidth() == 300.0)

    // Remove the value by setting nil
    store.saveConversationListWidth(0.0) // 0.0 is treated as "no value" in the implementation
    #expect(store.loadConversationListWidth() == 0.0)
}

// MARK: - SplitWidth Tests

@Test func splitWidthConstantsAreValid() {
    #expect(SplitWidth.defaultWidth > 0)
    #expect(SplitWidth.defaultMinimumWidth > 0)
    #expect(SplitWidth.defaultMaximumWidth > SplitWidth.defaultMinimumWidth)
    #expect(SplitWidth.defaultWidth >= SplitWidth.defaultMinimumWidth)
    #expect(SplitWidth.defaultWidth <= SplitWidth.defaultMaximumWidth)
}

@Test func splitWidthPreferredWidthHandlesZeroSavedWidth() throws {
    let databaseDirectory = try ChatPanelTestHelper.createTemporaryDirectory()
    defer { ChatPanelTestHelper.cleanupTemporaryDirectory(databaseDirectory) }

    let store = LocalStore(databaseDirectory: databaseDirectory)
    store.saveConversationListWidth(0.0)

    let preferredWidth = SplitWidth.preferredWidth(databaseDirectory: databaseDirectory)
    #expect(preferredWidth == SplitWidth.defaultWidth)
}

@Test func splitWidthPreferredWidthHandlesNegativeSavedWidth() throws {
    let databaseDirectory = try ChatPanelTestHelper.createTemporaryDirectory()
    defer { ChatPanelTestHelper.cleanupTemporaryDirectory(databaseDirectory) }

    let store = LocalStore(databaseDirectory: databaseDirectory)
    store.saveConversationListWidth(-100.0)

    let preferredWidth = SplitWidth.preferredWidth(databaseDirectory: databaseDirectory)
    #expect(preferredWidth == SplitWidth.defaultWidth)
}

@Test func splitWidthPreferredWidthClampsToMinimum() throws {
    let databaseDirectory = try ChatPanelTestHelper.createTemporaryDirectory()
    defer { ChatPanelTestHelper.cleanupTemporaryDirectory(databaseDirectory) }

    let store = LocalStore(databaseDirectory: databaseDirectory)
    store.saveConversationListWidth(Double(SplitWidth.defaultMinimumWidth - 50))

    let preferredWidth = SplitWidth.preferredWidth(databaseDirectory: databaseDirectory)
    #expect(preferredWidth == SplitWidth.defaultMinimumWidth)
}

@Test func splitWidthPreferredWidthClampsToMaximum() throws {
    let databaseDirectory = try ChatPanelTestHelper.createTemporaryDirectory()
    defer { ChatPanelTestHelper.cleanupTemporaryDirectory(databaseDirectory) }

    let store = LocalStore(databaseDirectory: databaseDirectory)
    store.saveConversationListWidth(Double(SplitWidth.defaultMaximumWidth + 100))

    let preferredWidth = SplitWidth.preferredWidth(databaseDirectory: databaseDirectory)
    #expect(preferredWidth == SplitWidth.defaultMaximumWidth)
}

@Test func splitWidthPersistenceConfigDefaultCreation() throws {
    let databaseDirectory = try ChatPanelTestHelper.createTemporaryDirectory()
    defer { ChatPanelTestHelper.cleanupTemporaryDirectory(databaseDirectory) }

    let config = SplitWidthPersistence.Config.default(databaseDirectory: databaseDirectory)

    #expect(config.defaultWidth == SplitWidth.defaultWidth)
    #expect(config.minimumWidth == SplitWidth.defaultMinimumWidth)
    #expect(config.maximumWidth == SplitWidth.defaultMaximumWidth)
    // LocalStore should be properly initialized
    #expect(config.store.loadConversationListWidth() >= 0.0)
}

// MARK: - ChatPanelPlugin Tests

@MainActor
@Test func chatPanelPluginInstanceProperties() {
    let plugin = ChatPanelPlugin()
    #expect(!plugin.id.isEmpty)
    #expect(plugin.id.contains("chat"))
    #expect(!plugin.name.isEmpty)
    #expect(plugin.order > 0)
    #expect(plugin.policy == .alwaysOn)
}

// MARK: - Edge Cases and Boundary Tests

@Test func localStoreHandlesConcurrentAccess() throws {
    let databaseDirectory = try ChatPanelTestHelper.createTemporaryDirectory()
    defer { ChatPanelTestHelper.cleanupTemporaryDirectory(databaseDirectory) }

    let store = LocalStore(databaseDirectory: databaseDirectory)

    // Test that the store can handle concurrent operations without crashing
    let group = DispatchGroup()

    for i in 0..<10 {
        group.enter()
        DispatchQueue.global().async {
            store.saveConversationListWidth(Double(i * 10))
            let value = store.loadConversationListWidth()
            group.leave()
            // Verify that some value was successfully stored
            #expect(value >= 0.0)
        }
    }

    // Wait for all operations to complete
    group.wait()
}

@Test func localStoreHandlesLargeWidthValues() throws {
    let databaseDirectory = try ChatPanelTestHelper.createTemporaryDirectory()
    defer { ChatPanelTestHelper.cleanupTemporaryDirectory(databaseDirectory) }

    let store = LocalStore(databaseDirectory: databaseDirectory)

    let extremeValues: [Double] = [1_000_000, -1_000_000, Double.greatestFiniteMagnitude, .infinity, -.infinity]

    for value in extremeValues {
        store.saveConversationListWidth(value)
        let loaded = store.loadConversationListWidth()
        #expect(loaded == value || loaded == 0.0) // Either saved correctly or defaulted to 0
    }
}

@Test func splitWidthWidthCalculationAccuracy() throws {
    let databaseDirectory = try ChatPanelTestHelper.createTemporaryDirectory()
    defer { ChatPanelTestHelper.cleanupTemporaryDirectory(databaseDirectory) }

    let testCases: [(saved: Double, expected: CGFloat)] = [
        (280, 280), // Default value
        (220, 220), // Minimum value
        (960, 960), // Maximum value
        (350, 350), // Middle value
        (500, 500), // Large value
    ]

    for testCase in testCases {
        let store = LocalStore(databaseDirectory: databaseDirectory)
        store.saveConversationListWidth(testCase.saved)

        let result = SplitWidth.preferredWidth(databaseDirectory: databaseDirectory)
        #expect(result == testCase.expected)
    }
}

// MARK: - Data Validation Tests

@Test func localStoreUUIDValidation() throws {
    let databaseDirectory = try ChatPanelTestHelper.createTemporaryDirectory()
    defer { ChatPanelTestHelper.cleanupTemporaryDirectory(databaseDirectory) }

    let store = LocalStore(databaseDirectory: databaseDirectory)

    // Test valid UUIDs
    let validUUIDs = [
        UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!,
        UUID()
    ]

    for uuid in validUUIDs {
        store.saveSelectedConversationID(uuid)
        #expect(store.loadSelectedConversationID() == uuid)
    }

    // Test that invalid UUID strings return nil
    store.saveSelectedConversationID(nil)
    #expect(store.loadSelectedConversationID() == nil)
}

// MARK: - Performance Tests

@Test func localStorePerformanceTest() throws {
    let databaseDirectory = try ChatPanelTestHelper.createTemporaryDirectory()
    defer { ChatPanelTestHelper.cleanupTemporaryDirectory(databaseDirectory) }

    let store = LocalStore(databaseDirectory: databaseDirectory)

    // Measure write performance
    let writeStart = Date()
    for i in 0..<100 {
        store.saveConversationListWidth(Double(i))
    }
    let writeDuration = Date().timeIntervalSince(writeStart)

    // Should complete 100 writes in less than 1 second
    #expect(writeDuration < 1.0)

    // Measure read performance
    let readStart = Date()
    for _ in 0..<100 {
        _ = store.loadConversationListWidth()
    }
    let readDuration = Date().timeIntervalSince(readStart)

    // Should complete 100 reads in less than 0.1 seconds
    #expect(readDuration < 0.1)
}

// MARK: - Integration Tests

@Test func chatPanelPluginIntegrationTest() throws {
    let databaseDirectory = try ChatPanelTestHelper.createTemporaryDirectory()
    defer { ChatPanelTestHelper.cleanupTemporaryDirectory(databaseDirectory) }

    // Test the full flow of width persistence
    let store = LocalStore(databaseDirectory: databaseDirectory)

    // Initial state
    #expect(store.loadConversationListWidth() == 0.0)
    var preferredWidth = SplitWidth.preferredWidth(databaseDirectory: databaseDirectory)
    #expect(preferredWidth == SplitWidth.defaultWidth)

    // Save a custom width
    let customWidth: Double = 400.0
    store.saveConversationListWidth(customWidth)

    // Verify persistence
    #expect(store.loadConversationListWidth() == customWidth)
    preferredWidth = SplitWidth.preferredWidth(databaseDirectory: databaseDirectory)
    #expect(preferredWidth == CGFloat(customWidth))

    // Verify consistency across store instances
    let newStore = LocalStore(databaseDirectory: databaseDirectory)
    #expect(newStore.loadConversationListWidth() == customWidth)
}
