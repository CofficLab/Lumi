import AppKit
import OSLog
import Sparkle

@MainActor
final class UpdateController: NSObject, SPUUpdaterDelegate {
    static let shared = UpdateController()

    private lazy var updaterController: SPUStandardUpdaterController = {
        let controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        // 同步设置正确的 feed URL，避免使用 Info.plist 中的默认值
        controller.updater.setFeedURL(primaryFeedURL)
        os_log(.info, "[UpdateController] Initial feed URL: %{public}@", primaryFeedURL.absoluteString)
        // 启动 updater
        controller.startUpdater()
        return controller
    }()

    private var pendingImmediateInstallHandler: (() -> Void)?

    /// 主 feed URL（根据架构选择对应的 appcast）
    private var primaryFeedURL: URL {
        #if arch(arm64)
        URL(string: "https://s.kuaiyizhi.cn/lumi/appcast-arm64.xml")!
        #else
        URL(string: "https://s.kuaiyizhi.cn/lumi/appcast-x86_64.xml")!
        #endif
    }

    /// 备用 feed URL（GitHub Release，根据架构选择对应的 appcast）
    private var fallbackFeedURL: URL {
        #if arch(arm64)
        URL(string: "https://github.com/CofficLab/Lumi/releases/latest/download/appcast-arm64.xml")!
        #else
        URL(string: "https://github.com/CofficLab/Lumi/releases/latest/download/appcast-x86_64.xml")!
        #endif
    }

    /// 缓存网络检测结果，避免每次检查都做网络请求
    private var lastDetectionTime: Date?

    var updater: SPUUpdater {
        updaterController.updater
    }

    override init() {
        super.init()
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

    /// 检测可用的 feed URL 并设置给 Sparkle
    ///
    /// 在应用启动时调用一次。先尝试自有服务器，不可达则使用 GitHub。
    func setupFeedURLIfNeeded() async {
        // 30 分钟内不重复检测
        if let lastDetectionTime,
           Date().timeIntervalSince(lastDetectionTime) < 1800 {
            return
        }

        let url = await detectFeedURL()
        lastDetectionTime = Date()

        // setFeedURL 必须在主线程调用
        await MainActor.run {
            updaterController.updater.setFeedURL(url)
            os_log(.info, "[UpdateController] Feed URL set to: %{public}@", url.absoluteString)
        }
    }

    /// 检测哪个 feed URL 可用
    private func detectFeedURL() async -> URL {
        // 先尝试主 URL（自有服务器）
        if await isURLReachable(primaryFeedURL) {
            os_log(.info, "[UpdateController] Primary feed reachable")
            return primaryFeedURL
        }

        // fallback 到 GitHub
        os_log(.info, "[UpdateController] Primary unreachable, using GitHub fallback")
        return fallbackFeedURL
    }

    /// 快速检测 URL 是否可达（HEAD 请求， 5 秒超时）
    private func isURLReachable(_ url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }

    func checkForUpdates() {
        // 确保 feed URL 已设置（通过访问 lazy var 触发初始化）
        _ = updaterController
        updaterController.checkForUpdates(nil)
    }

    func updater(
        _ updater: SPUUpdater,
        willInstallUpdateOnQuit item: SUAppcastItem,
        immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
    ) -> Bool {
        pendingImmediateInstallHandler = immediateInstallHandler
        NotificationCenter.postAppUpdateReadyToInstall(version: item.displayVersionString)
        return true
    }

    @objc private func handleCheckForUpdatesRequest() {
        checkForUpdates()
    }

    @objc private func handleInstallPreparedAppUpdateRequest() {
        guard let pendingImmediateInstallHandler else { return }
        pendingImmediateInstallHandler()
    }
}
