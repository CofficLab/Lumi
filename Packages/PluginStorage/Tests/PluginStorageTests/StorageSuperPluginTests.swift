import Foundation
import KernelCore
import ProviderStorage
import Testing
@testable import PluginStorage

@Test @MainActor func storagePluginRegistersItsServiceAndCreatesScopedDirectories() throws {
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

@MainActor
private func isDirectory(_ url: URL) -> Bool {
    var isDirectory = ObjCBool(false)
    return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
}
