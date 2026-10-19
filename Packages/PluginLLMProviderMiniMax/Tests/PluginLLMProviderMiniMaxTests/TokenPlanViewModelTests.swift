import Foundation
import Testing
import KitLLM
@testable import PluginLLMProviderMiniMax

/// `TokenPlanViewModel` 的状态流转与请求抑制策略。
///
/// 这层负责「什么时候该发请求」：TTL 未过不发、切换供应商时取消在途请求。
/// 它不回归就会静默退化成每次定时 tick 都打一次配额接口。
@MainActor
@Suite("配额 ViewModel")
struct TokenPlanViewModelTests {

    /// 5xx 响应会触发 `VendorAPIService` 的指数退避重试，单次刷新耗时
    /// 可达数秒；测试等待必须留足余量，否则会把「还没重试完」误判成失败。
    private static let slowFlushTimeout: Duration = .seconds(10)
    private static let fastFlushTimeout: Duration = .seconds(2)

    // MARK: - 初始状态

    @Test("初始为加载中且没有 chip 文案")
    func startsLoadingWithoutChipText() {
        let viewModel = makeViewModel(network: StubLLMNetwork(json: StubPayload.tokenPlanSuccess))

        #expect(viewModel.status == .loading)
        #expect(viewModel.statusBarText == nil)
        #expect(viewModel.revision == 0)
    }

    @Test("非成功状态都不产生 chip 文案", arguments: [
        TokenPlanStatus.loading, .authError, .unavailable
    ])
    func nonSuccessStatesHaveNoChipText(status: TokenPlanStatus) {
        let viewModel = makeViewModel(network: StubLLMNetwork(json: StubPayload.tokenPlanSuccess))
        viewModel.previewStatus = status

        #expect(viewModel.statusBarText == nil)
    }

    // MARK: - 刷新

    @Test("刷新后写入状态并递增 revision")
    func refreshAppliesStatusAndBumpsRevision() async throws {
        let (key, viewModel, network) = freshViewModelWithKey()

        viewModel.refresh()
        try await Self.waitUntilRevision(viewModel, equals: 1, timeout: Self.fastFlushTimeout)

        #expect(network.requestCount == 1)
        #expect(viewModel.statusBarText == "81% · 98%")
        #expect(viewModel.revision == 1)
    }

    @Test("请求失败时状态收敛为对应错误而非崩溃")
    func refreshFailureConvergesToErrorState() async throws {
        let key = TestKeychain.uniqueKey("fail")
        TestKeychain.set("test-key", forKey: key)
        defer { TestKeychain.set(nil, forKey: key) }

        // 用不可重试的传输错误：`VendorAPIService` 只对 timeout / 断网等瞬态
        // 错误退避重试，`badURL` 会立即失败，测试无需等待数秒重试链。
        // 测试目标是「任何失败都归一为 unavailable」，不涉及重试策略本身。
        let network = StubLLMNetwork.failing(URLError(.badURL))
        let viewModel = makeViewModel(network: network, key: key)

        viewModel.refresh()
        try await Self.waitUntilRevision(viewModel, equals: 1, timeout: Self.fastFlushTimeout)

        #expect(viewModel.status == .unavailable)
        #expect(viewModel.statusBarText == nil)
        #expect(viewModel.revision == 1)
    }

    @Test("空 Key 时短路为 authError 且不发请求")
    func refreshWithoutAPIKeyShortCircuits() async throws {
        let key = TestKeychain.uniqueKey("noKey")
        TestKeychain.set(nil, forKey: key)

        let network = StubLLMNetwork(json: StubPayload.tokenPlanSuccess)
        let viewModel = makeViewModel(network: network, key: key)

        viewModel.refresh()
        try await Self.waitUntilRevision(viewModel, equals: 1, timeout: Self.fastFlushTimeout)

        #expect(viewModel.status == .authError)
        #expect(network.requestCount == 0)
    }

    // MARK: - TTL 抑制

    @Test("TTL 内重复调用 refreshIfNeeded 不再发请求")
    func ttlSuppressesDuplicateRequests() async throws {
        let (_, viewModel, network) = freshViewModelWithKey()

        viewModel.refresh()
        try await Self.waitUntilRevision(viewModel, equals: 1, timeout: Self.fastFlushTimeout)
        #expect(network.requestCount == 1)

        for _ in 0..<5 {
            viewModel.refreshIfNeeded()
        }
        try await Task.yield()

        #expect(network.requestCount == 1)
        #expect(viewModel.revision == 1)
    }

    @Test("显式 refresh 绕过 TTL 强制请求")
    func explicitRefreshBypassesTTL() async throws {
        let (_, viewModel, network) = freshViewModelWithKey()

        viewModel.refresh()
        try await Self.waitUntilRevision(viewModel, equals: 1, timeout: Self.fastFlushTimeout)
        viewModel.refresh()
        try await Self.waitUntilRevision(viewModel, equals: 2, timeout: Self.fastFlushTimeout)

        #expect(network.requestCount == 2)
        #expect(viewModel.revision == 2)
    }

    @Test("连续 refresh 只保留最后一次结果")
    func consecutiveRefreshKeepsLatestResult() async throws {
        let (_, viewModel, _) = freshViewModelWithKey()

        for _ in 0..<3 {
            viewModel.refresh()
        }
        try await Self.waitUntilRevision(viewModel, equals: 1, timeout: Self.fastFlushTimeout)

        #expect(viewModel.statusBarText == "81% · 98%")
    }

    // MARK: - 取消

    @Test("cancelPendingFetch 后迟到的响应不写入状态")
    func cancelledFetchDoesNotApplyLateResult() async throws {
        let (_, viewModel, _) = freshViewModelWithKey()

        viewModel.refresh()
        viewModel.cancelPendingFetch()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.status == .loading)
        #expect(viewModel.revision == 0)
    }

    @Test("取消后仍可重新拉取")
    func canRefreshAgainAfterCancel() async throws {
        let (_, viewModel, network) = freshViewModelWithKey()

        viewModel.cancelPendingFetch()
        viewModel.refresh()
        try await Self.waitUntilRevision(viewModel, equals: 1, timeout: Self.fastFlushTimeout)

        #expect(network.requestCount == 1)
        #expect(viewModel.statusBarText == "81% · 98%")
    }

    // MARK: - Helpers

    /// 生成一组「带 Key + 带 ViewModel + 带网络桩」的测试夹具。
    ///
    /// 每次调用都生成独立的 storageKey，避免测试间相互污染；Key 与网络桩
    /// 的清理交给调用方的 defer 链。
    private func freshViewModelWithKey() -> (
        key: String, viewModel: TokenPlanViewModel, network: StubLLMNetwork
    ) {
        let key = TestKeychain.uniqueKey("vm")
        TestKeychain.set("test-key", forKey: key)
        let network = StubLLMNetwork(json: StubPayload.tokenPlanSuccess)
        let viewModel = makeViewModel(network: network, key: key)
        return (key, viewModel, network)
    }

    private func makeViewModel(
        network: StubLLMNetwork,
        key: String? = nil
    ) -> TokenPlanViewModel {
        TokenPlanViewModel(
            apiService: VendorAPIService(networkProvider: network),
            apiKeyStorageKey: key ?? TestKeychain.uniqueKey("default")
        )
    }

    /// 轮询等待异步刷新落地到**指定 revision**。
    ///
    /// `refresh()` 内部起 Task 后立即返回，测试必须等到 revision 达到目标值
    /// 才能断言；只等到 `> 0` 会在「第二次 refresh」测试里误把首次刷新后的状态
    /// 当作最终结果，让 revision 永远停在 1。
    @MainActor
    private static func waitUntilRevision(
        _ viewModel: TokenPlanViewModel,
        equals target: Int,
        timeout: Duration
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if viewModel.revision >= target { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record(
            "等待 ViewModel 刷新超时：期望 revision >= \(target)，实际 \(viewModel.revision)"
        )
    }
}
