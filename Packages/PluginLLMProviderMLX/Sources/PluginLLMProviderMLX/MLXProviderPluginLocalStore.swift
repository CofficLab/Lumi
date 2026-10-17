import Foundation

/// MLX Provider 插件本地存储
///
/// 负责持久化下载限速设置。
/// 存储位置：由 `onBoot` 注入的 `pluginDataDirectory(for: id)/settings.plist`
final class MLXProviderPluginLocalStore: @unchecked Sendable {
    static let shared = MLXProviderPluginLocalStore()

    private let queue = DispatchQueue(label: "com.coffic.lumi.plugin.llm-provider-mlx.store", qos: .userInitiated)
    private let fileURL: URL

    private init() {
        let directory = MLXProviderRuntime.settingsDirectory()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("settings.plist")
    }

    /// 测试用：以临时目录构造隔离实例。
    init(settingsDirectory: URL) {
        try? FileManager.default.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)
        fileURL = settingsDirectory.appendingPathComponent("settings.plist")
    }

    // MARK: - 下载限速

    /// 已保存的限速值（bytes/s）；nil 或非正值表示不限速。
    var downloadSpeedLimit: Int? {
        queue.sync { readDict()[MLXDownloadManager.downloadSpeedLimitKey] as? Int }
    }

    func setDownloadSpeedLimit(_ value: Int?) {
        queue.sync {
            var dict = readDict()
            if let value, value > 0 {
                dict[MLXDownloadManager.downloadSpeedLimitKey] = value
            } else {
                dict.removeValue(forKey: MLXDownloadManager.downloadSpeedLimitKey)
            }
            writeDict(dict)
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

    private func writeDict(_ dict: [String: Any]) {
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: dict,
            format: .binary,
            options: 0
        ) else {
            return
        }
        try? data.write(to: fileURL, options: .atomic)
    }
}
