import Foundation
import KitLLM
import Testing
@testable import PluginLLMProviderMiniMax

/// 配额请求失败后，工具栏 chip 必须明确呈现失败，而不是永远停在 Loading。
///
/// ## 为什么要有这条测试
///
/// `TokenPlanViewModel.statusBarText` 曾对 `.loading` / `.authError` /
/// `.unavailable` 一律返回 `nil`，而工具栏把「没有文案」统一渲染成不可点击的
/// `loadingChip`。结果：
/// - 失败后 chip 永远显示「Loading...」，用户分不清「还在加载」与「已经失败」；
/// - chip 没有 Button / popover，失败原因与已有的手动刷新入口都不可达；
/// - 失败时 `apply` 仍推进 `lastUpdateTime`，TTL 把后续重试也一起抑制掉。
///
/// 修复后：失败态要有明确文案、chip 仍然可点开详情、失败不推进 TTL。
@MainActor
@Suite("配额失败态的工具栏呈现")
struct TokenPlanFailurePresentationTests {

    // MARK: - Chip 文案

    @Test("加载中显示加载文案")
    func loadingShowsLoadingText() {
        let viewModel = makeViewModel()
        viewModel.previewStatus = .loading

        #expect(viewModel.statusBarText == pluginLocalization.string("Loading..."))
    }

    @Test("认证失败显示失败文案而不是加载文案")
    func authErrorShowsFailureText() {
        let viewModel = makeViewModel()
        viewModel.previewStatus = .authError

        let text = viewModel.statusBarText
        #expect(text != nil, "认证失败时不应没有 chip 文案")
        #expect(text != pluginLocalization.string("Loading..."), "认证失败不应显示加载文案")
        #expect(text == pluginLocalization.string("Authentication failed"))
    }

    @Test("配额不可用显示失败文案而不是加载文案")
    func unavailableShowsFailureText() {
        let viewModel = makeViewModel()
        viewModel.previewStatus = .unavailable

        let text = viewModel.statusBarText
        #expect(text != nil, "配额不可用时不应没有 chip 文案")
        #expect(text != pluginLocalization.string("Loading..."), "配额不可用不应显示加载文案")
        #expect(text == pluginLocalization.string("Unable to fetch quota info"))
    }

    @Test("成功状态仍返回原有配额文案")
    func successKeepsQuotaText() {
        let viewModel = makeViewModel()
        viewModel.previewStatus = .success(TokenPlanPreviewFixtures.allPlans)

        #expect(viewModel.statusBarText == TokenPlanData.statusBarText(from: TokenPlanPreviewFixtures.allPlans))
        #expect(viewModel.statusBarText != nil)
    }

    // MARK: - Chip 可交互性

    @Test("失败态的 chip 仍然可点开详情（存在 popover 入口）")
    func failureChipRemainsInteractive() {
        // 失败态必须走「带 Button + popover 的 chip」分支，而不是 loading 分支。
        // 这里以 ViewModel 暴露的 chip 呈现模式作为可断言的契约。
        let viewModel = makeViewModel()
        viewModel.previewStatus = .authError

        #expect(
            viewModel.chipPresentation == .interactive,
            "失败态 chip 不可交互，用户无法查看错误详情或手动刷新"
        )
        #expect(viewModel.chipPresentation == .interactive, "加载态 chip 也不该是不可交互的 loading")
    }

    @Test("加载中的 chip 呈现为加载态")
    func loadingChipShowsLoadingPresentation() {
        let viewModel = makeViewModel()
        viewModel.previewStatus = .loading

        #expect(viewModel.chipPresentation == .loading)
    }

    @Test("成功态的 chip 呈现为可交互")
    func successChipIsInteractive() {
        let viewModel = makeViewModel()
        viewModel.previewStatus = .success(TokenPlanPreviewFixtures.allPlans)

        #expect(viewModel.chipPresentation == .interactive)
    }

    // MARK: - TTL 抑制

    @Test("失败后不推进 TTL，下一次定时 tick 会重新尝试")
    func failureDoesNotSuppressRetry() async throws {
        let key = TestKeychain.uniqueKey("fail-ttl")
        TestKeychain.set("test-key", forKey: key)
        defer { TestKeychain.set(nil, forKey: key) }

        // 不可重试的传输错误：`VendorAPIService` 只对 timeout / 断网等瞬态错误
        // 退避重试，`badURL` 会立即失败，测试无需等待数秒重试链。
        let network = StubLLMNetwork.failing(URLError(.badURL))
        let viewModel = makeViewModel(network: network, key: key)

        viewModel.refresh()
        try await Self.waitUntilRevision(viewModel, equals: 1, timeout: Self.fastFlushTimeout)

        #expect(viewModel.status == .unavailable)

        // 失败不应把「最近一次成功」推进到此刻：TTL 判定必须认为缓存已过期，
        // 否则用户只能等 5 分钟或手动触发其它生命周期事件才能重试。
        viewModel.refreshIfNeeded()
        try await Self.waitUntilRevision(viewModel, equals: 2, timeout: Self.fastFlushTimeout)

        #expect(network.requestCount == 2, "失败后应允许立即重试")
    }

    @Test("成功后仍然推进 TTL，抑制重复请求")
    func successStillSuppressesDuplicateRequests() async throws {
        let key = TestKeychain.uniqueKey("success-ttl")
        TestKeychain.set("test-key", forKey: key)
        defer { TestKeychain.set(nil, forKey: key) }

        let network = StubLLMNetwork(json: StubPayload.tokenPlanSuccess)
        let viewModel = makeViewModel(network: network, key: key)

        viewModel.refresh()
        try await Self.waitUntilRevision(viewModel, equals: 1, timeout: Self.fastFlushTimeout)

        for _ in 0..<5 {
            viewModel.refreshIfNeeded()
        }
        try await Task.yield()

        #expect(network.requestCount == 1, "成功后仍应按 TTL 抑制重复请求")
    }

    // MARK: - Helpers

    private static let fastFlushTimeout: Duration = .seconds(5)

    private func makeViewModel(
        network: StubLLMNetwork = StubLLMNetwork(json: StubPayload.tokenPlanSuccess),
        key: String? = nil
    ) -> TokenPlanViewModel {
        TokenPlanViewModel(
            apiService: VendorAPIService(networkProvider: network),
            apiKeyStorageKey: key ?? TestKeychain.uniqueKey("default")
        )
    }

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
