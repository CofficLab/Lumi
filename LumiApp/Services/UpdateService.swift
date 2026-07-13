import AppKit
import SuperLogKit
import os
import Sparkle

@MainActor
final class UpdateService: NSObject, SPUUpdaterDelegate, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "core.updater")
    nonisolated static let emoji = "⬆️"
    nonisolated static let verbose = false

    static let shared = UpdateService()

    /// 延迟初始化 updaterController，避免在应用启动时阻塞主线程。
    /// Sparkle 的 SPUStandardUpdaterController 初始化涉及内部状态检查、
    /// 定时器注册等操作，推迟到实际需要时再创建。
    private(set) var updaterController: SPUStandardUpdaterController?

    private var pendingImmediateInstallHandler: (() -> Void)?

    /// 当前生效的 feed URL。初始用主 feed，setupFeedURLIfNeeded 探测后会更新为可达 URL。
    /// Sparkle 通过 SPUUpdaterDelegate.feedURLString(for:) 在每次检查更新时读取它。
    private var resolvedFeedURL: URL

    /// 主 feed URL（根据架构选择对应的 appcast）
    /// nonisolated：仅返回编译期常量，无实例状态访问，可安全在后台线程读取
    private nonisolated var primaryFeedURL: URL { Self.defaultFeedURL }

    /// 主 feed URL 的静态入口，供初始化器在 super.init 之前使用
    private nonisolated static let defaultFeedURL: URL = {
        #if arch(arm64)
        URL(string: "https://s.kuaiyizhi.cn/lumi/appcast-arm64.xml")!
        #else
        URL(string: "https://s.kuaiyizhi.cn/lumi/appcast-x86_64.xml")!
        #endif
    }()

    /// 备用 feed URL（GitHub Release，根据架构选择对应的 appcast）
    /// nonisolated：仅返回编译期常量，无实例状态访问，可安全在后台线程读取
    private nonisolated var fallbackFeedURL: URL {
        #if arch(arm64)
        URL(string: "https://github.com/CofficLab/Lumi/releases/latest/download/appcast-arm64.xml")!
        #else
        URL(string: "https://github.com/CofficLab/Lumi/releases/latest/download/appcast-x86_64.xml")!
        #endif
    }

    /// 缓存网络检测结果，避免每次检查都做网络请求
    private var lastDetectionTime: Date?

    override init() {
        self.resolvedFeedURL = Self.defaultFeedURL
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
    /// 外部调用方（如 CheckForUpdatesViewModel）需要在订阅 updater 属性前
    /// 先调用此方法确保 updater 已就绪。
    @MainActor
    func ensureUpdaterInitialized() {
        guard updaterController == nil else { return }

        let controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        // 不再调用已废弃的 setFeedURL；feed URL 改由
        // SPUUpdaterDelegate.feedURLString(for:) 在检查更新时动态返回（见下方实现）。
        // 一次性迁移：清除历史版本通过 setFeedURL 写入 UserDefaults 的旧 feed URL，
        // 确保 delegate 提供的 URL 生效。
        _ = controller.updater.clearFeedURLFromUserDefaults()
        if Self.verbose {
            Self.logger.info("\(self.t)Initial feed URL: \(self.resolvedFeedURL.absoluteString, privacy: .public)")
        }
        // 启动 updater
        controller.startUpdater()
        self.updaterController = controller
    }

    /// 检测可用的 feed URL 并设置给 Sparkle
    ///
    /// 在应用启动时调用一次。先尝试自有服务器，不可达则使用 GitHub。
    /// 该方法也会触发 updaterController 的延迟初始化。
    ///
    /// 线程模型：网络探测（含 5 秒超时的 HEAD 请求）放在 detached 后台 Task
    /// 中执行，不在主线程上推进；只有 Sparkle 必须在主线程的操作
    /// （初始化 controller）才 hop 回 MainActor。
    /// 检测结果写入 resolvedFeedURL，由 feedURLString(for:) delegate 返回给 Sparkle。
    func setupFeedURLIfNeeded() {
        // 30 分钟内不重复检测（仅读取本地字段，不阻塞）
        if let lastDetectionTime,
           Date().timeIntervalSince(lastDetectionTime) < 1800 {
            return
        }

        // 标记检测时间，避免短时间内重复发起网络请求
        lastDetectionTime = Date()

        // 脱离主 actor 在后台线程执行网络探测
        Task.detached(priority: .utility) { [primaryFeedURL, fallbackFeedURL] in
            let url = await Self.detectFeedURL(
                primary: primaryFeedURL,
                fallback: fallbackFeedURL
            )

            // 写回 resolvedFeedURL 必须在 MainActor 上（属性为 @MainActor 隔离）
            await MainActor.run {
                self.ensureUpdaterInitialized()
                self.resolvedFeedURL = url
                if UpdateService.verbose {
                    Self.logger.info("\(UpdateService.t)Feed URL set to: \(url.absoluteString, privacy: .public)")
                }
            }
        }
    }

    /// 检测哪个 feed URL 可用
    /// nonisolated + async：纯网络探测，不访问任何实例状态，
    /// 由调用方传入待探测的 URL，可在任意后台线程执行。
    private nonisolated static func detectFeedURL(
        primary: URL,
        fallback: URL
    ) async -> URL {
        // 先尝试主 URL（自有服务器）
        if await isURLReachable(primary) {
            if verbose {
                logger.info("\(t)Primary feed reachable")
            }
            return primary
        }

        // fallback 到 GitHub
        if verbose {
            logger.info("\(t)Primary unreachable, using GitHub fallback")
        }
        return fallback
    }

    /// 快速检测 URL 是否可达（HEAD 请求，5 秒超时）
    /// nonisolated + async：可在任意后台线程执行，不占用主线程。
    private nonisolated static func isURLReachable(_ url: URL) async -> Bool {
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
            logger.warning("\(t)URL reachability check failed: \(error.localizedDescription)")
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

    /// Sparkle 推荐的动态 feed URL 提供方式（取代已废弃的 setFeedURL）。
    /// 每次检查更新时 Sparkle 会回调此方法，返回当前探测到的可达 feed URL。
    func feedURLString(for updater: SPUUpdater) -> String? {
        resolvedFeedURL.absoluteString
    }

    @objc private func handleCheckForUpdatesRequest() {
        checkForUpdates()
    }

    @objc private func handleInstallPreparedAppUpdateRequest() {
        guard let pendingImmediateInstallHandler else { return }
        pendingImmediateInstallHandler()
    }
}
