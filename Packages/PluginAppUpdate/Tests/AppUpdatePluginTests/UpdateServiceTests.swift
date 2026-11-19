import Foundation
import ProviderAppUpdate
import Testing
@testable import AppUpdatePlugin

@Suite("App update services")
struct UpdateServiceTests {
    @Test("tracks update lifecycle and clears the ready version on reset")
    func updateStateTransitions() async {
        let state = UpdateServiceStateMachine()
        #expect(await state.state == .idle)
        #expect(await state.latestVersion == nil)

        await state.beginChecking()
        #expect(await state.state == .checking)
        await state.beginDownloading()
        #expect(await state.state == .downloading)
        await state.markReadyToInstall(version: "5.2.1")
        #expect(await state.state == .readyToInstall)
        #expect(await state.latestVersion == "5.2.1")
        await state.beginInstalling()
        #expect(await state.state == .installing)
        await state.markError()
        #expect(await state.state == .error)

        await state.updateCachedFeedURL(URL(string: "https://example.com/appcast.xml")!)
        await state.reset()
        #expect(await state.state == .idle)
        #expect(await state.latestVersion == nil)
        #expect(await state.cachedFeedURL?.absoluteString == "https://example.com/appcast.xml")
    }

    @Test("falls back, caches detection, reprobes at expiry, and resets on feed changes")
    func detectsAndCachesReachableFeed() async {
        let primary = URL(string: "https://primary.example.com/appcast.xml")!
        let fallback = URL(string: "https://fallback.example.com/appcast.xml")!
        let nextPrimary = URL(string: "https://preview.example.com/appcast.xml")!
        let nextFallback = URL(string: "https://preview-fallback.example.com/appcast.xml")!
        let checker = MutableReachabilityChecker(reachable: [primary: false, fallback: true, nextPrimary: true])
        let clock = TestClock(Date(timeIntervalSince1970: 1_000))
        let detector = FeedURLDetector(
            initialURL: primary,
            reachabilityChecker: checker,
            fallbackURL: fallback,
            cacheWindow: 100,
            clock: { clock.now() }
        )

        await detector.detectIfNeeded()
        #expect(await detector.resolvedFeedURL == fallback)
        #expect(await checker.calls() == [primary])

        clock.set(Date(timeIntervalSince1970: 1_099))
        await detector.detectIfNeeded()
        #expect(await checker.calls() == [primary])

        clock.set(Date(timeIntervalSince1970: 1_100))
        await detector.detectIfNeeded()
        #expect(await checker.calls() == [primary, primary])

        await detector.updateFeedURLs(primary: nextPrimary, fallback: nextFallback)
        #expect(await detector.resolvedFeedURL == nextPrimary)
        await detector.detectIfNeeded()
        #expect(await detector.resolvedFeedURL == nextPrimary)
        #expect(await checker.calls().last == nextPrimary)

        await detector.forceRedetect()
        #expect(await checker.calls().suffix(2) == [nextPrimary, nextPrimary])
    }

    @Test("does not let an old in-flight probe overwrite a newly selected feed")
    func ignoresProbeForPreviousFeedConfiguration() async {
        let oldPrimary = URL(string: "https://old.example.com/appcast.xml")!
        let oldFallback = URL(string: "https://old-fallback.example.com/appcast.xml")!
        let newPrimary = URL(string: "https://new.example.com/appcast.xml")!
        let newFallback = URL(string: "https://new-fallback.example.com/appcast.xml")!
        let gate = ProbeGate()
        let detector = FeedURLDetector(
            initialURL: oldPrimary,
            reachabilityChecker: GatedReachabilityChecker(gate: gate),
            fallbackURL: oldFallback
        )

        let pendingProbe = Task { await detector.detectIfNeeded() }
        await gate.waitUntilProbeStarts()
        await detector.updateFeedURLs(primary: newPrimary, fallback: newFallback)
        await gate.resume(returning: true)
        await pendingProbe.value

        #expect(await detector.resolvedFeedURL == newPrimary)
    }
}

@Suite("Update channel persistence (#524)")
@MainActor
struct UpdateChannelPersistenceTests {
    @Test("持久化失败时保留旧通道，不把未落盘的选择当作生效")
    func keepsOldSelectionWhenPersistenceFails() throws {
        let directory = AppUpdateTestDoubles.makeTemporaryDirectory("service-unwritable")
        let occupied = directory.appendingPathComponent("settings.plist")
        try FileManager.default.createDirectory(at: occupied, withIntermediateDirectories: true)
        let store = AppUpdatePluginLocalStore(settingsDirectory: directory)
        let service = UpdateService(store: store)

        service.setChannel(.preview)

        // UI 绑定 service.channel：失败时必须仍是旧选择，重启后不会悄悄回退。
        #expect(service.channel == .stable)
        #expect(store.channel == .stable)
    }

    @Test("持久化成功后立即应用新通道并落盘")
    func appliesNewSelectionAfterSuccessfulPersist() throws {
        let directory = AppUpdateTestDoubles.makeTemporaryDirectory("service-ok")
        let store = AppUpdatePluginLocalStore(settingsDirectory: directory)
        let service = UpdateService(store: store)

        service.setChannel(.preview)

        #expect(service.channel == .preview)
        #expect(store.channel == .preview)
    }
}

@Suite("通道切换后重新探测 feed（#236）")
@MainActor
struct UpdateChannelSwitchProbeTests {
    @Test("切换通道后自动探测新通道主源，不可达时落到备用源")
    func setChannelReprobesNewChannelFeed() async {
        // setChannel 的 URL 一律来自 UpdateFeedURLProvider（静态生产清单），
        // 因此测试直接用真实 URL，把可达性交给注入的假 checker 决定。
        let previewPrimary = UpdateFeedURLProvider.primary(for: .preview)
        let previewFallback = UpdateFeedURLProvider.fallback(for: .preview)
        let checker = MutableReachabilityChecker(reachable: [
            previewPrimary: false,
            previewFallback: true,
        ])
        let detector = FeedURLDetector(
            initialURL: UpdateFeedURLProvider.primary(for: .stable),
            reachabilityChecker: checker,
            fallbackURL: UpdateFeedURLProvider.fallback(for: .stable)
        )
        let directory = AppUpdateTestDoubles.makeTemporaryDirectory("channel-switch-probe")
        let store = AppUpdatePluginLocalStore(settingsDirectory: directory)
        let service = UpdateService(store: store, feedURLDetector: detector)

        service.setChannel(.preview)
        let url = await service.feedURLAfterPendingPreparation()

        // 修复前：切换不排入探测任务，Sparkle 后台检查会一直读未探测的
        // Preview 主源，主源不可达时无法发现备用源上的更新。
        #expect(url == previewFallback)
        #expect(await checker.calls() == [previewPrimary])
    }
}

@Suite("启动 feed 准备完成后自动启动 updater（#234）")
@MainActor
struct StartupUpdaterInitializationTests {
    @Test("feed 准备完成后自动初始化 updater，无需手动检查")
    func setupInitializesUpdaterAfterPreparation() async {
        let stablePrimary = UpdateFeedURLProvider.primary(for: .stable)
        let checker = MutableReachabilityChecker(reachable: [stablePrimary: true])
        let detector = FeedURLDetector(
            initialURL: stablePrimary,
            reachabilityChecker: checker,
            fallbackURL: UpdateFeedURLProvider.fallback(for: .stable)
        )
        let directory = AppUpdateTestDoubles.makeTemporaryDirectory("startup-updater-init")
        let store = AppUpdatePluginLocalStore(settingsDirectory: directory)
        let service = UpdateService(store: store, feedURLDetector: detector)

        // 测试进程不拉起真实 Sparkle：注入替身记录初始化调用。
        var initializationCalls = 0
        service.updaterInitializationStub = { initializationCalls += 1 }

        service.setupFeedURLIfNeeded()
        _ = await service.feedURLAfterPendingPreparation()

        // 修复前：启动只探测 feed，Sparkle 控制器保持 nil，配置的自动检查
        // 要等用户手动点一次「检查更新」才开始工作。
        #expect(initializationCalls == 1)
        #expect(service.updaterController == nil)
    }
}

@Suite("等待中的检查绑定发起时的通道（#235）")
@MainActor
struct WaitingCheckChannelBindingTests {
    @Test("通道切换后，等待旧准备的检查被丢弃，不再驱动 Sparkle 检查")
    func waitingCheckDiscardedAfterChannelSwitch() async {
        let stablePrimary = UpdateFeedURLProvider.primary(for: .stable)
        let gate = ProbeGate()
        // 闸门只拦第一次探测（stable 主源）；切通道后的 Preview 探测直接
        // 返回不可达，让新通道准备走完整个流程。
        let detector = FeedURLDetector(
            initialURL: stablePrimary,
            reachabilityChecker: FirstProbeGatedChecker(gate: gate),
            fallbackURL: UpdateFeedURLProvider.fallback(for: .stable)
        )
        let directory = AppUpdateTestDoubles.makeTemporaryDirectory("waiting-check-channel")
        let store = AppUpdatePluginLocalStore(settingsDirectory: directory)
        let service = UpdateService(store: store, feedURLDetector: detector)

        var checkCalls = 0
        service.updaterInitializationStub = {}
        service.sparkleCheckStub = { checkCalls += 1 }

        // 检查 A：等待 stable 准备，探测被闸门挂起。
        service.checkForUpdates()
        await gate.waitUntilProbeStarts()

        // 等待期间切到 Preview：旧准备被取消，新通道的探测流程跑完。
        service.setChannel(.preview)
        _ = await service.feedURLAfterPendingPreparation()

        // 放行旧探测：检查 A 的迟到结果不得驱动新通道的 Sparkle 检查。
        // 修复前：旧检查无条件继续，读到的 resolvedFeedURL 是新通道尚未
        // 探测完的主源，备用源选择被绕过。
        await gate.resume(returning: true)
        for _ in 0..<10 {
            if checkCalls != 0 { break }
            await Task.yield()
        }
        #expect(checkCalls == 0, "通道切换后等待旧准备的检查必须被丢弃")
    }

    @Test("通道未切换时等待的检查正常驱动 Sparkle 检查")
    func waitingCheckProceedsWhenChannelUnchanged() async {
        let stablePrimary = UpdateFeedURLProvider.primary(for: .stable)
        let gate = ProbeGate()
        let detector = FeedURLDetector(
            initialURL: stablePrimary,
            reachabilityChecker: GatedReachabilityChecker(gate: gate),
            fallbackURL: UpdateFeedURLProvider.fallback(for: .stable)
        )
        let directory = AppUpdateTestDoubles.makeTemporaryDirectory("waiting-check-proceeds")
        let store = AppUpdatePluginLocalStore(settingsDirectory: directory)
        let service = UpdateService(store: store, feedURLDetector: detector)

        var checkCalls = 0
        service.updaterInitializationStub = {}
        service.sparkleCheckStub = { checkCalls += 1 }

        service.checkForUpdates()
        await gate.waitUntilProbeStarts()
        await gate.resume(returning: true)
        for _ in 0..<10 {
            if checkCalls != 0 { break }
            await Task.yield()
        }
        #expect(checkCalls == 1, "通道未变时等待的检查要正常执行")
    }
}

/// 闸门只拦第一次探测，后续探测立即返回不可达。
private actor FirstProbeGatedChecker: FeedURLReachabilityChecker {
    let gate: ProbeGate
    private var probeCount = 0

    init(gate: ProbeGate) {
        self.gate = gate
    }

    func isReachable(_ url: URL) async -> Bool {
        probeCount += 1
        if probeCount == 1 { return await gate.wait() }
        return false
    }
}

private actor MutableReachabilityChecker: FeedURLReachabilityChecker {
    private var reachability: [URL: Bool]
    private var probedURLs: [URL] = []

    init(reachable: [URL: Bool]) {
        self.reachability = reachable
    }

    func isReachable(_ url: URL) async -> Bool {
        probedURLs.append(url)
        return reachability[url, default: false]
    }

    func calls() -> [URL] { probedURLs }
}

private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date

    init(_ value: Date) { self.value = value }

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set(_ value: Date) {
        lock.lock()
        defer { lock.unlock() }
        self.value = value
    }
}

private struct GatedReachabilityChecker: FeedURLReachabilityChecker {
    let gate: ProbeGate

    func isReachable(_ url: URL) async -> Bool {
        await gate.wait()
    }
}

private actor ProbeGate {
    private var started = false
    private var startedContinuation: CheckedContinuation<Void, Never>?
    private var resultContinuation: CheckedContinuation<Bool, Never>?

    func wait() async -> Bool {
        started = true
        startedContinuation?.resume()
        startedContinuation = nil
        return await withCheckedContinuation { resultContinuation = $0 }
    }

    func waitUntilProbeStarts() async {
        guard !started else { return }
        await withCheckedContinuation { startedContinuation = $0 }
    }

    func resume(returning value: Bool) {
        resultContinuation?.resume(returning: value)
        resultContinuation = nil
    }
}
