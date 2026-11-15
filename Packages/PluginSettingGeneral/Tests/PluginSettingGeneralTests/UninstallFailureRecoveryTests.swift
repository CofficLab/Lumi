import Foundation
import ProviderUninstall
import Testing
@testable import PluginSettingGeneral

/// 回归 #304：卸载前内核已停止、插件与 Provider 全部注销。失败浮层的
/// 关闭动作只恢复窗口会留下服务全部失效的空壳应用，必须显式退出应用，
/// 由用户重新启动。
@Suite("卸载失败恢复", .serialized)
@MainActor
struct UninstallFailureRecoveryTests {

    @Test("卸载抛错后关闭失败浮层必须退出应用，不得只恢复窗口")
    func failureCloseQuitsApplication() async {
        let capability = StubUninstallCapability(
            outcome: .failure(NSError(domain: "test", code: 1))
        )
        var quitCount = 0
        let viewModel = makeViewModel(capability: capability) { quitCount += 1 }

        viewModel.performUninstall()
        await waitUntil { capability.uninstallCallCount == 1 }
        await settle()

        let close = UninstallOverlayWindowController.shared.onClose
        #expect(close != nil, "失败浮层必须接上关闭回调")
        close?()
        #expect(quitCount == 1, "失败后关闭必须退出应用，而不是恢复空壳窗口")
        UninstallOverlayWindowController.shared.close()
    }

    @Test("部分数据清除失败（result.succeeded == false）同样必须退出")
    func partialFailureCloseQuitsApplication() async {
        let capability = StubUninstallCapability(
            outcome: .partial([
                UninstallFailure(targetID: "a", location: "/tmp/a", message: "permission denied"),
            ])
        )
        var quitCount = 0
        let viewModel = makeViewModel(capability: capability) { quitCount += 1 }

        viewModel.performUninstall()
        await waitUntil { capability.uninstallCallCount == 1 }
        await settle()

        let close = UninstallOverlayWindowController.shared.onClose
        #expect(close != nil)
        close?()
        #expect(quitCount == 1, "部分失败同样停掉了内核，关闭必须退出应用")
        UninstallOverlayWindowController.shared.close()
    }

    @Test("失败关闭会先释放浮层再退出")
    func failureCloseReleasesOverlayBeforeQuitting() async {
        let capability = StubUninstallCapability(
            outcome: .failure(NSError(domain: "test", code: 2))
        )
        var overlayStillVisibleAtQuit: Bool?
        let viewModel = makeViewModel(capability: capability) {
            overlayStillVisibleAtQuit = UninstallOverlayWindowController.shared.onClose != nil
        }

        viewModel.performUninstall()
        await waitUntil { capability.uninstallCallCount == 1 }
        await settle()

        UninstallOverlayWindowController.shared.onClose?()
        #expect(overlayStillVisibleAtQuit == false, "退出前必须先关闭浮层，避免残留窗口")
    }

    // MARK: - Helpers

    private func makeViewModel(
        capability: StubUninstallCapability,
        quit: @escaping @MainActor () -> Void
    ) -> GeneralSettingsViewModel {
        GeneralSettingsViewModel(
            docsCapability: GeneralSettingsDocsCapabilityAdapter(docsProvider: nil),
            updateChannelCapability: GeneralSettingsUpdateChannelCapabilityAdapter(updateProvider: nil),
            diagnosticsCapability: GeneralSettingsDiagnosticsCapabilityAdapter(diagnosticsProvider: nil),
            storageCapability: GeneralSettingsStorageCapabilityAdapter(storageProvider: nil),
            uninstallCapability: capability,
            quitApplication: quit
        )
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<10_000 {
            if condition() { return }
            await Task.yield()
        }
        Issue.record("等待卸载执行超时")
    }

    private func settle() async {
        for _ in 0..<50 {
            await Task.yield()
        }
    }
}

/// 可配置失败形态的卸载能力桩。
@MainActor
private final class StubUninstallCapability: GeneralSettingsUninstallCapability {
    enum Outcome {
        case failure(Error)
        case partial([UninstallFailure])
    }

    var isUninstallAvailable = true
    private(set) var uninstallCallCount = 0
    private let outcome: Outcome

    init(outcome: Outcome) {
        self.outcome = outcome
    }

    func scanUninstall() async -> UninstallScan { UninstallScan() }

    func prepareForUninstall() async {}

    func uninstall(options: UninstallOptions) async throws -> UninstallResult {
        uninstallCallCount += 1
        switch outcome {
        case .failure(let error):
            throw error
        case .partial(let failures):
            return UninstallResult(
                removedTargetIDs: [],
                failures: failures,
                applicationMovedToTrash: false
            )
        }
    }
}