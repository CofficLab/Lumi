import AppKit
import MagicKit
import OSLog
import Sparkle

/// 更新控制器，负责应用的自动更新功能
@MainActor
class UpdateController: NSObject, SuperLog {
    nonisolated static let emoji = "✨"
    static let verbose = true

    // MARK: - Properties

    /// Sparkle 更新控制器，提供应用自动更新功能
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    // MARK: - Initialization

    override init() {
        super.init()
        setupNotifications()
        if Self.verbose {
            os_log("\(self.t)更新控制器已初始化")
        }
    }

    // MARK: - Public Methods

    /// 检查更新
    func checkForUpdates() {
        if Self.verbose {
            os_log("\(self.t)开始检查更新...")
        }
        updaterController.checkForUpdates(nil)
    }

    // MARK: - Private Methods

    /// 设置通知监听
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCheckForUpdatesRequest),
            name: .checkForUpdates,
            object: nil
        )
    }

    /// 处理检查更新请求
    @objc private func handleCheckForUpdatesRequest() {
        checkForUpdates()
    }
}
