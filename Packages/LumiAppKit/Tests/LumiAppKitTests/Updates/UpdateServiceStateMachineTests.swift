import Foundation
import Testing
@testable import LumiAppKit

@Suite("UpdateServiceStateMachine")
struct UpdateServiceStateMachineTests {

    // MARK: - 状态转换

    @Test
    func initialStateIsIdle() async {
        let detector = makeMockDetector()
        let machine = UpdateServiceStateMachine(feedURLDetector: detector)

        let state = await machine.state
        #expect(state == .idle)
    }

    @Test
    func beginCheckingTransitionsToChecking() async {
        let machine = UpdateServiceStateMachine(feedURLDetector: makeMockDetector())
        await machine.beginChecking()

        let state = await machine.state
        #expect(state == .checking)
    }

    @Test
    func beginDownloadingTransitionsToDownloading() async {
        let machine = UpdateServiceStateMachine(feedURLDetector: makeMockDetector())
        await machine.beginDownloading()

        let state = await machine.state
        #expect(state == .downloading)
    }

    @Test
    func markReadyToInstallRecordsVersionAndHandler() async {
        let machine = UpdateServiceStateMachine(feedURLDetector: makeMockDetector())
        var handlerCalled = false
        await machine.markReadyToInstall(
            version: "1.2.3",
            installHandler: { handlerCalled = true }
        )

        let state = await machine.state
        let version = await machine.latestVersion
        #expect(state == .readyToInstall)
        #expect(version == "1.2.3")

        // 执行安装回调
        let executed = await machine.executePendingInstallHandler()
        #expect(executed == true)
        #expect(handlerCalled == true)
    }

    @Test
    func beginInstallingTransitionsToInstalling() async {
        let machine = UpdateServiceStateMachine(feedURLDetector: makeMockDetector())
        await machine.beginInstalling()

        let state = await machine.state
        #expect(state == .installing)
    }

    @Test
    func markErrorTransitionsToError() async {
        let machine = UpdateServiceStateMachine(feedURLDetector: makeMockDetector())
        await machine.markError()

        let state = await machine.state
        #expect(state == .error)
    }

    @Test
    func resetClearsAllState() async {
        let machine = UpdateServiceStateMachine(feedURLDetector: makeMockDetector())
        await machine.markReadyToInstall(
            version: "1.2.3",
            installHandler: {}
        )
        await machine.reset()

        let state = await machine.state
        let version = await machine.latestVersion
        let hasPending = await machine.hasPendingInstall
        #expect(state == .idle)
        #expect(version == nil)
        #expect(hasPending == false)
    }

    // MARK: - 查询方法

    @Test
    func cachedFeedURLReturnsDetectorURL() async {
        let expectedURL = URL(string: "https://test.example/appcast.xml")!
        let detector = FeedURLDetector(initialURL: expectedURL)
        let machine = UpdateServiceStateMachine(feedURLDetector: detector)

        // 从 detector 同步到缓存
        await machine.syncFromDetector()
        let feedURL = await machine.cachedFeedURL
        #expect(feedURL == expectedURL)
    }

    @Test
    func cachedFeedURLReturnsNilWhenNoDetector() async {
        let machine = UpdateServiceStateMachine()

        let feedURL = await machine.cachedFeedURL
        #expect(feedURL == nil)
    }

    @Test
    func executePendingInstallHandlerReturnsFalseWhenNone() async {
        let machine = UpdateServiceStateMachine(feedURLDetector: makeMockDetector())

        let executed = await machine.executePendingInstallHandler()
        #expect(executed == false)
    }

    @Test
    func executePendingInstallHandlerTransitionsToInstalling() async {
        let machine = UpdateServiceStateMachine(feedURLDetector: makeMockDetector())
        await machine.markReadyToInstall(
            version: "1.2.3",
            installHandler: {}
        )

        _ = await machine.executePendingInstallHandler()
        let state = await machine.state
        #expect(state == .installing)
    }

    @Test
    func hasPendingInstallReturnsTrueWhenHandlerSet() async {
        let machine = UpdateServiceStateMachine(feedURLDetector: makeMockDetector())
        await machine.markReadyToInstall(
            version: "1.2.3",
            installHandler: {}
        )

        let hasPending = await machine.hasPendingInstall
        #expect(hasPending == true)
    }

    @Test
    func hasPendingInstallReturnsFalseAfterExecute() async {
        let machine = UpdateServiceStateMachine(feedURLDetector: makeMockDetector())
        await machine.markReadyToInstall(
            version: "1.2.3",
            installHandler: {}
        )
        _ = await machine.executePendingInstallHandler()

        let hasPending = await machine.hasPendingInstall
        #expect(hasPending == false)
    }

    // MARK: - 辅助方法

    private func makeMockDetector() -> FeedURLDetector {
        FeedURLDetector(initialURL: UpdateFeedURLProvider.primary)
    }
}
