@testable import EditorSwiftPlugin
import Foundation
import LumiKernel
import Testing
import XcodeKit

@MainActor
@Test func buildServerStoreUsesPluginDirectoryName() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("EditorSwiftBuildServerStoreTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let pluginDirectory = tempRoot.appendingPathComponent(EditorSwiftBuildServerStore.pluginDirectoryName, isDirectory: true)
    try FileManager.default.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)

    let store = XcodeBuildServerStore(pluginDirectoryURL: pluginDirectory)
    let workspacePath = "/tmp/Example.xcodeproj"
    let directory = store.ensureDirectory(forWorkspace: workspacePath)

    #expect(directory.path.hasPrefix(pluginDirectory.path))
    #expect(!directory.path.contains("EditorXcodePlugin"))
}

@MainActor
@Test func buildServerStoreMigratesLegacyEditorXcodePluginDirectory() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("EditorSwiftBuildServerStoreMigration-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let legacyDirectory = tempRoot.appendingPathComponent("EditorXcodePlugin", isDirectory: true)
    let projectHashDirectory = legacyDirectory.appendingPathComponent("abc123", isDirectory: true)
    try FileManager.default.createDirectory(at: projectHashDirectory, withIntermediateDirectories: true)
    let markerURL = projectHashDirectory.appendingPathComponent("buildServer.json")
    try Data("{}".utf8).write(to: markerURL)

    let pluginDirectory = tempRoot.appendingPathComponent(EditorSwiftBuildServerStore.pluginDirectoryName, isDirectory: true)

    EditorSwiftBuildServerStore.migrateLegacyStorageForTesting(
        legacyDirectory: legacyDirectory,
        pluginDirectory: pluginDirectory
    )

    #expect(!FileManager.default.fileExists(atPath: legacyDirectory.path))
    #expect(FileManager.default.fileExists(atPath: pluginDirectory.appendingPathComponent("abc123/buildServer.json").path))
}
