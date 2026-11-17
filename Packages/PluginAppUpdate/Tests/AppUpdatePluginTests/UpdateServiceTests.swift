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
