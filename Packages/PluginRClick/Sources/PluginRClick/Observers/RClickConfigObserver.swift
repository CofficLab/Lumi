import Foundation

/// 监听 Finder 扩展共享的 App Group 配置文件，并把外部写入重新装载到配置状态。
@MainActor
final class RClickConfigObserver {
    private let configManager: RClickConfigManager
    private var timer: Timer?
    private var lastModificationDate: Date?

    init(configManager: RClickConfigManager) {
        self.configManager = configManager
        lastModificationDate = modificationDate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let date = self.modificationDate(), date != self.lastModificationDate else { return }
            self.lastModificationDate = date
            self.configManager.loadConfig()
        }
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
    }

    private func modificationDate() -> Date? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: RClickConfigManager.appGroupId
        ) else { return nil }
        let url = RClickConfigManager.sharedConfigURL(in: container)
        return try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}
