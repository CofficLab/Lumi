import Foundation
import ProviderAppUpdate

/// App Update 插件本地存储
///
/// 负责持久化用户选择的更新通道（stable / beta）。
/// 存储位置：由 `onBoot` 注入的 `pluginDataDirectory(for: id)/settings.plist`
final class AppUpdatePluginLocalStore: @unchecked Sendable {
    static let shared = AppUpdatePluginLocalStore()

    private let queue = DispatchQueue(label: "com.coffic.lumi.plugin.app-update.store", qos: .userInitiated)
    private let fileURL: URL

    private init() {
        let directory = AppUpdateRuntime.settingsDirectory()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("settings.plist")
    }

    /// 测试用：以临时目录构造隔离实例。
    init(settingsDirectory: URL) {
        try? FileManager.default.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)
        fileURL = settingsDirectory.appendingPathComponent("settings.plist")
    }

    // MARK: - 更新通道

    var channel: AppUpdateChannel {
        queue.sync { readDict()[AppUpdateChannel.userDefaultsKey] as? String }
            .flatMap(AppUpdateChannel.init(rawValue:)) ?? .stable
    }

    /// 写入更新通道。
    ///
    /// 序列化或落盘失败时抛出，调用方据此保留旧选择，而不是把未持久化的
    /// 通道当作已生效（#524）。
    func setChannel(_ channel: AppUpdateChannel) throws {
        try queue.sync {
            var dict = readDict()
            dict[AppUpdateChannel.userDefaultsKey] = channel.rawValue
            try writeDict(dict)
        }
    }

    // MARK: - 私有辅助

    private func readDict() -> [String: Any] {
        guard let data = try? Data(contentsOf: fileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any]
        else {
            return [:]
        }
        return dict
    }

    private func writeDict(_ dict: [String: Any]) throws {
        let data = try PropertyListSerialization.data(
            fromPropertyList: dict,
            format: .binary,
            options: 0
        )
        try data.write(to: fileURL, options: .atomic)
    }
}
