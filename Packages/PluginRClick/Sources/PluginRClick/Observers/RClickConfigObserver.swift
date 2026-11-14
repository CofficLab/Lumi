import Foundation

/// 监听 Finder 扩展共享的 App Group 配置文件，并把外部写入重新装载到配置状态。
@MainActor
final class RClickConfigObserver {
    private let configManager: RClickConfigManager
    private let configURL: URL?
    private var timer: Timer?
    private var lastModificationDate: Date?

    init(configManager: RClickConfigManager, configURL: URL? = nil) {
        self.configManager = configManager
        self.configURL = configURL
        lastModificationDate = modificationDate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
    }

    // 在 loadConfig() 之后记录 mtime，吸收装载触发的自写回，避免每秒重载→保存死循环（#296）。
    func checkForChanges() {
        guard let date = modificationDate(), date != lastModificationDate else { return }
        configManager.loadConfig()
        lastModificationDate = modificationDate() ?? date
    }

    private func modificationDate() -> Date? {
        guard let url = configURL ?? defaultConfigURL() else { return nil }
        return try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }

    private func defaultConfigURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: RClickConfigManager.appGroupId)
            .map(RClickConfigManager.sharedConfigURL)
    }
}