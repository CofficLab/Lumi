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

    /// 当前 chip 文本；`nil` 表示无可展示数据（此时应显示加载态或隐藏 chip）。
    var statusBarText: String? {
        guard case let .success(plans) = status else { return nil }
        return TokenPlanData.statusBarText(from: plans)
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

    private func apply(_ newStatus: TokenPlanStatus) {
        status = newStatus
        lastUpdateTime = Date()
        revision &+= 1
    }

    #if DEBUG
    /// 预览 / 单测注入固定状态：不触网、不读 Keychain。
    var previewStatus: TokenPlanStatus {
        get { status }
        set {
            status = newValue
            lastUpdateTime = Date()
            revision &+= 1
        }
    }
    #endif
}
