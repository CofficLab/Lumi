import Foundation
import KernelCore
import ProviderStorage

/// Small, concurrency-safe bridge for services that are intentionally created
/// before the plugin lifecycle has a chance to inject the storage provider.
enum AppStoreConnectPluginRuntimeBridge {
    nonisolated(unsafe) static var dataRootDirectory: URL?
    nonisolated(unsafe) static var pluginSubdirectory: URL?

    static let pluginName = "AppStoreConnectPlugin"

    static let fallbackRootDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
    }()

    @MainActor
    static func configure(kernel: KernelCoreContainer, pluginID: String) {
        guard let storage = kernel.resolveProvider((any StorageProviding).self) else { return }
        dataRootDirectory = storage.dataRootDirectory
        pluginSubdirectory = storage.pluginDataDirectory(for: pluginID)
    }
}
