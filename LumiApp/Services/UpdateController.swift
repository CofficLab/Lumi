import AppKit
import SuperLogKit
import os
import Sparkle

@MainActor
final class UpdateController: NSObject, SPUUpdaterDelegate, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "core.updater")
    nonisolated static let emoji = "⬆️"

    static let shared = UpdateController()

    /// 延迟初始化 updaterController，避免在应用启动时阻塞主线程。
    /// Sparkle 的 SPUStandardUpdaterController 初始化涉及内部状态检查、
    /// 定时器注册等操作，推迟到实际需要时再创建。
    private(set) var updaterController: SPUStandardUpdaterController?

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

    /// 提供对 SPUUpdater 的安全访问。
    /// 如果 updaterController 尚未初始化，返回 nil。
    var updater: SPUUpdater? {
        updaterController?.updater
    }

    /// 延迟初始化 Sparkle updater，避免在应用启动时阻塞主线程。
    /// 该方法保证返回有效的 updaterController 实例。
    @MainActor
    private func ensureUpdaterInitialized() {
        guard updaterController == nil else { return }

        let controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        // 使用 primaryFeedURL 作为初始值，后续 setupFeedURLIfNeeded 会更新为可达的 URL
        controller.updater.setFeedURL(primaryFeedURL)
        Self.logger.info("\(self.t)Initial feed URL: \(self.primaryFeedURL.absoluteString, privacy: .public)")
        // 启动 updater
        controller.startUpdater()
        self.updaterController = controller
    }

    /// 检测可用的 feed URL 并设置给 Sparkle
    ///
    /// 在应用启动时调用一次。先尝试自有服务器，不可达则使用 GitHub。
    /// 该方法也会触发 updaterController 的延迟初始化。
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
            ensureUpdaterInitialized()
            updaterController?.updater.setFeedURL(url)
            Self.logger.info("\(UpdateController.t)Feed URL set to: \(url.absoluteString, privacy: .public)")
        }
    }

    /// 检测哪个 feed URL 可用
    private func detectFeedURL() async -> URL {
        // 先尝试主 URL（自有服务器）
        if await isURLReachable(primaryFeedURL) {
            Self.logger.info("\(self.t)Primary feed reachable")
            return primaryFeedURL
        }

        // fallback 到 GitHub
        Self.logger.info("\(self.t)Primary unreachable, using GitHub fallback")
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
        // 延迟初始化 updaterController
        ensureUpdaterInitialized()
        updaterController?.checkForUpdates(nil)
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
