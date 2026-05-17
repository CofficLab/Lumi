import AppKit
import MagicKit
import Sparkle

/// 更新控制器，负责应用的自动更新功能
@MainActor
final class UpdateController: NSObject, SuperLog, SPUUpdaterDelegate {
    nonisolated static let emoji = "✨"
    nonisolated static let verbose: Bool = false
    // MARK: - Properties

    static let shared = UpdateController()

    /// Sparkle 更新控制器，提供应用自动更新功能
    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: self,
        userDriverDelegate: nil
    )

    private var pendingImmediateInstallHandler: (() -> Void)?

    var updater: SPUUpdater {
        updaterController.updater
    }

    // MARK: - Initialization

    override init() {
        super.init()
        setupNotifications()
        if Self.verbose {
            AppLogger.core.info("\(self.t)更新控制器已初始化")
        }
    }

    // MARK: - Public Methods

    /// 检查更新
    func checkForUpdates() {
        if Self.verbose {
            AppLogger.core.info("\(self.t)开始检查更新...")
        }
        updaterController.checkForUpdates(nil)
    }

    // MARK: - SPUUpdaterDelegate

    func updater(
        _ updater: SPUUpdater,
        willInstallUpdateOnQuit item: SUAppcastItem,
        immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
    ) -> Bool {
        pendingImmediateInstallHandler = immediateInstallHandler
        NotificationCenter.postAppUpdateReadyToInstall(version: item.displayVersionString)

        if Self.verbose {
            AppLogger.core.info("\(self.t)更新已后台下载完成，等待用户安装: \(item.displayVersionString)")
        }

        return true
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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInstallPreparedAppUpdateRequest),
            name: .installPreparedAppUpdate,
            object: nil
        )
    }

    /// 处理检查更新请求
    @objc private func handleCheckForUpdatesRequest() {
        checkForUpdates()
    }

    /// 处理安装已下载更新请求
    @objc private func handleInstallPreparedAppUpdateRequest() {
        guard let pendingImmediateInstallHandler else {
            if Self.verbose {
                AppLogger.core.warning("\(self.t)收到安装请求，但没有待安装更新")
            }
            return
        }

        if Self.verbose {
            AppLogger.core.info("\(self.t)开始安装已下载更新")
        }

        pendingImmediateInstallHandler()
    }
}
