import Foundation
import KernelCore
import ProviderStorage
import Testing
@testable import PluginStorage

@Test @MainActor
func storagePluginRegistersItsServiceAndCreatesScopedDirectories() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginStorageTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let plugin = try StorageSuperPlugin(dataRootDirectory: root)
    let kernel = KernelCoreContainer()

    try plugin.onBoot(kernel: kernel)

    let storage = try #require(kernel.resolveProvider((any StorageProviding).self))
    #expect(storage.dataRootDirectory == root.standardizedFileURL)

    let pluginDirectory = storage.pluginDataDirectory(for: "com.example.test-plugin")
    let coreDirectory = storage.coreDataDirectory()
    #expect(pluginDirectory == root.appendingPathComponent("com.example.test-plugin", isDirectory: true))
    #expect(coreDirectory == root.appendingPathComponent("Core", isDirectory: true))
    #expect(isDirectory(pluginDirectory))
    #expect(isDirectory(coreDirectory))
    #expect(plugin.id == "com.coffic.lumi.plugin.storage")
    #expect(plugin.metadata.policy == .alwaysOn)
}

@Test @MainActor
func storagePluginKeepsAHostProvidedService() throws {
    let hostRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginStorageHostTests-\(UUID().uuidString)", isDirectory: true)
    let pluginRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginStoragePluginTests-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: hostRoot)
        try? FileManager.default.removeItem(at: pluginRoot)
    }

    let hostService = TestStorageProvider(dataRootDirectory: hostRoot)
    let kernel = KernelCoreContainer()
    try kernel.registerProvider((any StorageProviding).self, hostService)

    try StorageSuperPlugin(dataRootDirectory: pluginRoot).onBoot(kernel: kernel)

    let resolved = try #require(kernel.resolveProvider((any StorageProviding).self))
    #expect(resolved === hostService)
    #expect(resolved.dataRootDirectory == hostRoot.standardizedFileURL)
}

@Test
func storagePathResolverCreatesTheVersionedRoot() throws {
    let root = try StoragePathResolver.defaultDataRootDirectory(
        bundle: .main,
        fallbackBundleID: "com.example.storage-tests",
        fallbackMajorVersion: 7
    )

    #expect(root.lastPathComponent.hasPrefix("db_"))
    #expect(root.path.contains("com.example.storage-tests") || Bundle.main.bundleIdentifier != nil)
    #expect(FileManager.default.fileExists(atPath: root.path))
}

@MainActor
private final class TestStorageProvider: StorageProviding {
    let dataRootDirectory: URL

    init(dataRootDirectory: URL) {
        self.dataRootDirectory = dataRootDirectory.standardizedFileURL
    }

    var allVersionDataRootDirectories: [URL] { [dataRootDirectory] }

    func pluginDataDirectory(for pluginID: String) -> URL {
        dataRootDirectory.appendingPathComponent(pluginID, isDirectory: true)
    }

    func coreDataDirectory() -> URL {
        dataRootDirectory.appendingPathComponent("Core", isDirectory: true)
    }

    func dataRootDirectorySizeInBytes() async -> Int64 { 0 }
}

@MainActor
private func isDirectory(_ url: URL) -> Bool {
    var isDirectory = ObjCBool(false)
    return FileManager.default.fileExists(
        atPath: url.path,
        isDirectory: &isDirectory
    ) && isDirectory.boolValue
}
