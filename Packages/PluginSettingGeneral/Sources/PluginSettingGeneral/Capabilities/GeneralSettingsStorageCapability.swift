import ProviderStorage

#if canImport(AppKit)
import AppKit
#endif

/// 通用设置页需要的最小存储信息能力。
@MainActor
protocol GeneralSettingsStorageCapability: AnyObject {
    var isStorageAvailable: Bool { get }
    func storageSizeInBytes() async -> Int64?
    func openStorageDirectory()
}

/// 默认实现：把 `StorageProviding` 收窄为本插件的存储信息能力。
@MainActor
final class GeneralSettingsStorageCapabilityAdapter: GeneralSettingsStorageCapability {
    private let storageProvider: (any StorageProviding)?

    init(storageProvider: (any StorageProviding)?) {
        self.storageProvider = storageProvider
    }

    var isStorageAvailable: Bool {
        storageProvider != nil
    }

    func storageSizeInBytes() async -> Int64? {
        guard let storageProvider else { return nil }
        return await storageProvider.dataRootDirectorySizeInBytes()
    }

    func openStorageDirectory() {
        guard let storageURL = storageProvider?.dataRootDirectory else { return }
        // 打开版本根目录的父目录，让用户可以看到 v4/v5/v6 的全部数据。
        let storageParentURL = storageURL.deletingLastPathComponent()

        #if canImport(AppKit)
        NSWorkspace.shared.open(storageParentURL)
        #endif
    }
}