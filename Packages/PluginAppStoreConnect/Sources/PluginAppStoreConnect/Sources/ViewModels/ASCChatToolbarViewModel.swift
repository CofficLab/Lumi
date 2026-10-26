import Foundation
import LumiLoggingKit
import os

/// Chat Toolbar 的 ASC 版本面板 ViewModel。
///
/// 职责：
/// - 观察当前项目路径变化，重新解析「项目 → ASC App」的绑定；
/// - 绑定解析优先级：项目配置 `.lumi/app-store-connect/app.json`
///   → Xcode 工程自动识别的 bundle ID；
/// - 拉取目标 App 的版本列表并向界面暴露状态。
///
/// 绑定解析是**本地同步**的（读文件 + 解析 pbxproj），因此项目切换后
/// `hasBinding` 立即可用，按钮的出现/消失不会滞后一帧；
/// 只有「查 App + 拉版本」是异步的。
///
/// 外部事件只从 ``ASCChatToolbarObserver`` 进入；ViewModel 不直接持有
/// `any *Providing`。
@MainActor
final class ASCChatToolbarViewModel: ObservableObject, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.app-store-connect",
        category: "ASCChatToolbarViewModel"
    )
    nonisolated static let emoji = "🏪"

    // MARK: - Published State

    /// 当前项目路径。
    @Published private(set) var projectPath: String?
    /// 解析出的项目绑定（本地即可确定，不需要网络）。
    @Published private(set) var binding: ASCAppBinding?
    /// 目标 App（需要向 ASC 查询才能确定）。
    @Published private(set) var app: AppStoreApp?
    /// 目标 App 的版本列表。
    @Published private(set) var versions: [AppStoreVersion] = []
    /// 是否正在加载。
    @Published private(set) var isLoading = false
    /// 错误信息（界面以横幅展示）。
    @Published private(set) var errorMessage: String?

    // MARK: - Internals

    /// ASC 客户端能力。
    ///
    /// **强引用**：Adapter 由插件入口内联创建，若这里用 `weak`，Adapter 会随
    /// 创建语句结束立即释放，能力调用将永远返回「不可用」。
    private let clientCapability: (any ASCChatClientCapability)?
    /// 按 bundle ID 缓存已解析的 App，避免每次切换项目都重新查询。
    private var resolvedAppsByBundleID: [String: AppStoreApp] = [:]
    /// 加载代次令牌：丢弃过期请求的结果。
    private var loadGeneration: UInt64 = 0

    init(clientCapability: (any ASCChatClientCapability)?) {
        self.clientCapability = clientCapability
    }

    // MARK: - Derived

    /// 当前项目是否绑定到了某个 ASC App。
    ///
    /// 未绑定时 Chat Toolbar 不展示该入口（由视图层收敛为空视图）。
    var hasBinding: Bool {
        binding != nil
    }

    /// 版本列表数量（用于按钮徽标）。
    var versionCount: Int {
        versions.count
    }

    // MARK: - External Events

    /// 项目切换（观察者触发）。
    func updateProjectPath(_ path: String?) {
        let normalized = path?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedValue = (normalized?.isEmpty == false) ? normalized : nil
        guard projectPath != normalizedValue else { return }

        projectPath = normalizedValue
        app = nil
        versions = []
        errorMessage = nil
        binding = nil

        guard let normalizedValue else { return }

        // 绑定解析是本地同步的：先给出结论，再异步拉取远端数据。
        guard let localBinding = Self.resolveBinding(projectPath: normalizedValue) else {
            return
        }
        binding = localBinding

        isLoading = true
        Task { await loadVersions(for: localBinding) }
    }

    /// 手动刷新（重新解析绑定并拉取版本）。
    func refresh() async {
        guard let projectPath else { return }
        let localBinding = Self.resolveBinding(projectPath: projectPath)
        binding = localBinding
        guard let localBinding else {
            app = nil
            versions = []
            isLoading = false
            return
        }
        await loadVersions(for: localBinding, forceRefresh: true)
    }

    // MARK: - Loading

    /// 拉取目标 App 及其版本列表。
    private func loadVersions(for binding: ASCAppBinding, forceRefresh: Bool = false) async {
        loadGeneration &+= 1
        let generation = loadGeneration
        isLoading = true
        errorMessage = nil

        guard let clientCapability else {
            errorMessage = ASCChatClientError.unavailable.errorDescription
            isLoading = false
            return
        }

        do {
            let resolvedApp = try await resolveApp(
                binding: binding,
                clientCapability: clientCapability,
                forceRefresh: forceRefresh
            )
            guard generation == loadGeneration else { return }

            guard let resolvedApp else {
                app = nil
                versions = []
                errorMessage = AppStoreConnectLocalization.string(
                    "No App Store Connect app matches this project. Check the bundle identifier or the app.json configuration."
                )
                isLoading = false
                return
            }

            app = resolvedApp
            let loadedVersions = try await clientCapability.listVersions(appID: resolvedApp.id)
            guard generation == loadGeneration else { return }
            versions = loadedVersions
            isLoading = false
        } catch {
            guard generation == loadGeneration else { return }
            versions = []
            errorMessage = Self.describe(error)
            isLoading = false
        }
    }

    /// 解析绑定对应的 ASC App。
    ///
    /// - `appID` 命中时直接按 ID 读取；否则按 bundle ID 查询（带缓存）。
    private func resolveApp(
        binding: ASCAppBinding,
        clientCapability: any ASCChatClientCapability,
        forceRefresh: Bool
    ) async throws -> AppStoreApp? {
        if let appID = binding.appID {
            return try await clientCapability.readApp(id: appID)
        }

        guard let bundleID = binding.bundleID else { return nil }
        if !forceRefresh, let cached = resolvedAppsByBundleID[bundleID] {
            return cached
        }
        let found = try await clientCapability.findApp(bundleID: bundleID)
        if let found {
            resolvedAppsByBundleID[bundleID] = found
        }
        return found
    }

    // MARK: - Helpers

    /// 本地解析「项目 → 绑定」。
    ///
    /// 优先级：项目配置 `app.json` → Xcode 工程自动识别的 bundle ID。
    static func resolveBinding(projectPath: String) -> ASCAppBinding? {
        if let configured = ASCAppBindingLoader.load(projectPath: projectPath) {
            return configured
        }
        guard let bundleID = ASCBundleIDDetector.detectBundleID(projectPath: projectPath) else {
            return nil
        }
        return ASCAppBinding(bundleID: bundleID)
    }

    private static func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
