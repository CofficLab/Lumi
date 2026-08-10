import Foundation
import LumiKernel

@MainActor
enum AppStorePromoRuntime {
    static private(set) var storageDirectory: URL?

    static func configure(kernel: LumiKernel) {
        configure(persistenceDirectory: kernel.storage?.pluginDataDirectory(for: "AppStorePromoDesigner"))
    }

    static func configure(persistenceDirectory: URL?) {
        storageDirectory = persistenceDirectory?.standardizedFileURL
        AppStorePromoWorkspaceStore.shared.configure(persistenceDirectory: storageDirectory)
    }
}
