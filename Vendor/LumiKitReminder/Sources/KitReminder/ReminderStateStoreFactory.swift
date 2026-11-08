import Foundation
import ProviderStorage

/// 提醒插件存储的装配入口。
///
/// 插件在 `onBoot(kernel:)` 里从内核解析 `StorageProviding`，
/// 再通过这里创建自己专属的状态存储：
///
/// ```swift
/// guard let storage = kernel.resolveProvider((any StorageProviding).self) else { return }
/// let store = ReminderStateStore.make(storage: storage, pluginID: Self.pluginID)
/// ```
///
/// 目录分配规则与 CofficLab 兄弟项目一致：每个插件一个独立子目录，
/// 状态文件写在其中，互不干扰。
public enum ReminderStateStoreFactory {
    /// 用宿主的 `StorageProviding` 为指定插件创建状态存储。
    ///
    /// - Parameters:
    ///   - storage: 宿主的存储能力。
    ///   - pluginID: 插件标识，用作目录名。
    /// - Returns: 指向 `<插件目录>/settings.plist` 的状态存储。
    @MainActor
    public static func make(storage: any StorageProviding, pluginID: String) -> ReminderStateStore {
        ReminderStateStore(directory: storage.pluginDataDirectory(for: pluginID))
    }
}

public extension ReminderStateStore {
    /// 用宿主的 `StorageProviding` 为指定插件创建状态存储。
    ///
    /// - Parameters:
    ///   - storage: 宿主的存储能力。
    ///   - pluginID: 插件标识，用作目录名。
    @MainActor
    static func make(storage: any StorageProviding, pluginID: String) -> ReminderStateStore {
        ReminderStateStoreFactory.make(storage: storage, pluginID: pluginID)
    }
}
