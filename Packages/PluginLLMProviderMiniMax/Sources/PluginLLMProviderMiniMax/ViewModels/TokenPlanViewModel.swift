import Foundation
import KitLLM
import LumiLoggingKit
import os

/// 工具栏配额 chip 的状态容器。
///
/// 只做三件事：按需拉取配额、按 TTL 抑制重复请求、把最新状态暴露给视图。
/// 定时器由 View 侧（``TokenPlanToolbarView``）驱动，出现 / 消失时自动启停，
/// 避免 chip 不可见时仍空转网络。
@MainActor
final class TokenPlanViewModel: ObservableObject {
    nonisolated private static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.llm-provider.minimax",
        category: "TokenPlanViewModel"
    )
    nonisolated static let emoji = "📊"

    /// 配额变化需要重新渲染时递增，供 View 用 `.id(revision)` 触发刷新。
    @Published private(set) var revision: Int = 0
    @Published private(set) var status: TokenPlanStatus = .loading

    /// 最近一次拉取完成的时间；详情面板用它标注数据新鲜度。
    ///
    /// 不做 `@Published`：刷新完成时 `revision` 一定自增，工具栏 View 读到
    /// 新的 `revision` 后重建弹窗内容，时间戳随之刷新，无需额外发布信号。
    private(set) var lastUpdatedAt: Date?

    /// API Key 的 Keychain storage key；与供应商本体共用同一份 Key。
    private let apiKeyStorageKey: String
    private let apiService: VendorAPIService

    private var lastUpdateTime: Date?
    private var fetchTask: Task<Void, Never>?

    /// 5 分钟内不重复请求：配额按 5 小时窗口重置，秒级刷新没有意义。
    private let cacheTTL: TimeInterval = 300

    init(apiService: VendorAPIService, apiKeyStorageKey: String) {
        self.apiService = apiService
        self.apiKeyStorageKey = apiKeyStorageKey
    }

    deinit {
        fetchTask?.cancel()
    }

    // MARK: - Public

    /// 工具栏 chip 的呈现方式。
    ///
    /// 失败态必须走 `.interactive`：chip 上挂了 Button + popover，
    /// 详情面板里已有失败文案与手动刷新按钮。失败若退化成 `.loading`，
    /// 用户既看不到原因也点不开详情，只能干等。
    enum ChipPresentation: Equatable {
        /// 加载中：不可点击的占位 chip。
        case loading
        /// 有文案且可点击（成功配额或失败提示）。
        case interactive
    }

    /// 当前 chip 文本。
    ///
    /// 成功时是配额摘要；失败时是失败原因；加载中时是加载文案。
    /// 三种状态都有文案，避免「没有文案」被渲染成无法区分的加载态。
    var statusBarText: String? {
        switch status {
        case .success(let plans):
            return TokenPlanData.statusBarText(from: plans)
        case .authError:
            return pluginLocalization.string("Authentication failed")
        case .unavailable:
            return pluginLocalization.string("Unable to fetch quota info")
        case .loading:
            return pluginLocalization.string("Loading...")
        }
    }

    /// chip 的呈现方式。
    ///
    /// 只有真正还在加载时才不可点击；失败态也必须可点开详情，
    /// 否则用户无法看到失败原因与手动刷新入口。
    var chipPresentation: ChipPresentation {
        switch status {
        case .loading:
            return .loading
        case .success, .authError, .unavailable:
            return .interactive
        }
    }

    /// 定时器 tick：仅在缓存过期时才真正发请求。
    func refreshIfNeeded() {
        guard isCacheStale else { return }
        refresh()
    }

    /// 强制刷新（详情面板的刷新按钮 / chip 首次出现）。
    func refresh() {
        fetchTask?.cancel()
        fetchTask = Task { [weak self] in
            guard let self else { return }
            let result = await TokenPlanService.fetchTokenPlan(
                apiService: self.apiService,
                apiKeyStorageKey: self.apiKeyStorageKey
            )
            guard !Task.isCancelled else { return }
            self.apply(result)
        }
    }

    /// 取消在途请求（chip 消失 / 插件关闭）。
    func cancelPendingFetch() {
        fetchTask?.cancel()
        fetchTask = nil
    }

    // MARK: - Derived

    private var isCacheStale: Bool {
        guard let lastUpdateTime else { return true }
        return Date().timeIntervalSince(lastUpdateTime) > cacheTTL
    }

    // MARK: - Setter

    /// 应用一次拉取结果。
    ///
    /// 只有**成功**才推进 TTL 时间戳：失败时保留旧时间戳，让下一次定时 tick
    /// 或重新出现 chip 时能立即重试。否则一次失败会把后续 5 分钟的刷新
    /// 全部抑制掉，用户既看不到原因也没法主动重试。
    private func apply(_ newStatus: TokenPlanStatus) {
        status = newStatus
        if case .success = newStatus {
            lastUpdateTime = Date()
            lastUpdatedAt = lastUpdateTime
        } else if lastUpdatedAt == nil {
            // 失败时也记录一次时间点：详情面板用它标注「最近一次尝试」。
            lastUpdatedAt = Date()
        }
        revision &+= 1
    }

    #if DEBUG
    /// 预览 / 单测注入固定状态：不触网、不读 Keychain。
    var previewStatus: TokenPlanStatus {
        get { status }
        set {
            status = newValue
            // 与 `apply` 保持同一套 TTL 语义：失败不推进 TTL。
            if case .success = newValue {
                lastUpdateTime = Date()
                lastUpdatedAt = lastUpdateTime
            } else if lastUpdatedAt == nil {
                lastUpdatedAt = Date()
            }
            revision &+= 1
        }
    }
    #endif
}
