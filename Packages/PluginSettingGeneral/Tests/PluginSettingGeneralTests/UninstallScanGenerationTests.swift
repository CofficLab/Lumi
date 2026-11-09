import Foundation
import ProviderUninstall
import Testing
@testable import PluginSettingGeneral

/// 回归 #1070：取消并重新打开卸载弹窗时，旧扫描不得覆盖新结果或提前解除加载态。
@Suite("卸载扫描代次", .serialized)
@MainActor
struct UninstallScanGenerationTests {
    private let scanA = UninstallScan(targets: [
        UninstallTarget(id: "a", kind: .caches, location: "/tmp/a", sizeInBytes: 1),
    ])
    private let scanB = UninstallScan(targets: [
        UninstallTarget(id: "b", kind: .applicationData, location: "/tmp/b", sizeInBytes: 2),
        UninstallTarget(id: "b2", kind: .preferences, location: "/tmp/b2", sizeInBytes: 3),
    ])

    @Test("旧扫描晚到不能覆盖新扫描结果")
    func staleScanCannotOverwriteNewerResult() async {
        let capability = DelayedUninstallCapability()
        let viewModel = makeViewModel(capability: capability)

        viewModel.beginUninstall()
        await waitForScanCount(1, in: capability)

        viewModel.cancelUninstallScan()
        viewModel.beginUninstall()
        await waitForScanCount(2, in: capability)

        capability.resumeScan(at: 1, with: scanB)
        await waitUntil { viewModel.uninstallScan == self.scanB }
        #expect(viewModel.uninstallScan == scanB)
        #expect(!viewModel.isScanningUninstall)

        capability.resumeScan(at: 0, with: scanA)
        await settle()
        #expect(viewModel.uninstallScan == scanB, "旧扫描 A 不得覆盖新扫描 B")
        #expect(!viewModel.isScanningUninstall)
    }

    @Test("旧扫描先完成不会提前解除新扫描的加载态")
    func staleScanCannotClearNewerLoadingState() async {
        let capability = DelayedUninstallCapability()
        let viewModel = makeViewModel(capability: capability)

        viewModel.beginUninstall()
        await waitForScanCount(1, in: capability)

        viewModel.cancelUninstallScan()
        viewModel.beginUninstall()
        await waitForScanCount(2, in: capability)

        // 旧扫描 A 先返回：此时 B 仍在进行。
        capability.resumeScan(at: 0, with: scanA)
        await settle()
        #expect(viewModel.isScanningUninstall, "B 未完成时确认按钮必须保持禁用")
        #expect(viewModel.uninstallScan == nil)

        capability.resumeScan(at: 1, with: scanB)
        await waitUntil { viewModel.uninstallScan == self.scanB }
        #expect(!viewModel.isScanningUninstall)
    }

    @Test("取消弹窗会失效在途扫描并复位加载态")
    func cancellingInvalidatesInFlightScan() async {
        let capability = DelayedUninstallCapability()
        let viewModel = makeViewModel(capability: capability)

        viewModel.beginUninstall()
        await waitForScanCount(1, in: capability)

        viewModel.cancelUninstallScan()
        #expect(!viewModel.isScanningUninstall)
        #expect(viewModel.uninstallScan == nil)

        capability.resumeScan(at: 0, with: scanA)
        await settle()
        #expect(viewModel.uninstallScan == nil, "已取消的扫描不得写回结果")
        #expect(!viewModel.isScanningUninstall)
    }

    @Test("重新打开弹窗会重新扫描并展示最新结果")
    func reopeningStartsFreshScan() async {
        let capability = DelayedUninstallCapability()
        let viewModel = makeViewModel(capability: capability)

        viewModel.beginUninstall()
        await waitForScanCount(1, in: capability)
        capability.resumeScan(at: 0, with: scanA)
        await waitUntil { viewModel.uninstallScan == self.scanA }

        viewModel.cancelUninstallScan()
        viewModel.beginUninstall()
        await waitForScanCount(2, in: capability)
        #expect(viewModel.isScanningUninstall)
        #expect(viewModel.uninstallScan == nil)

        capability.resumeScan(at: 1, with: scanB)
        await waitUntil { viewModel.uninstallScan == self.scanB }
        #expect(viewModel.uninstallScan == scanB)
        #expect(!viewModel.isScanningUninstall)
    }

    // MARK: - Helpers

    private func makeViewModel(capability: DelayedUninstallCapability) -> GeneralSettingsViewModel {
        GeneralSettingsViewModel(
            docsCapability: GeneralSettingsDocsCapabilityAdapter(docsProvider: nil),
            updateChannelCapability: GeneralSettingsUpdateChannelCapabilityAdapter(updateProvider: nil),
            diagnosticsCapability: GeneralSettingsDiagnosticsCapabilityAdapter(diagnosticsProvider: nil),
            storageCapability: GeneralSettingsStorageCapabilityAdapter(storageProvider: nil),
            uninstallCapability: capability
        )
    }

    private func waitForScanCount(
        _ count: Int,
        in capability: DelayedUninstallCapability
    ) async {
        for _ in 0..<10_000 {
            if capability.scanCallCount >= count { return }
            await Task.yield()
        }
        Issue.record("等待第 \(count) 次扫描启动超时")
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<10_000 {
            if condition() { return }
            await Task.yield()
        }
        Issue.record("等待扫描写回超时")
    }

    private func settle() async {
        for _ in 0..<50 {
            await Task.yield()
        }
    }
}

/// 可逐次手动完成的扫描能力，用于构造「旧任务晚到」的顺序。
@MainActor
private final class DelayedUninstallCapability: GeneralSettingsUninstallCapability {
    var isUninstallAvailable = true
    private(set) var scanCallCount = 0
    private var pendingScans: [CheckedContinuation<UninstallScan, Never>] = []

    func scanUninstall() async -> UninstallScan {
        scanCallCount += 1
        return await withCheckedContinuation { continuation in
            pendingScans.append(continuation)
        }
    }

    func resumeScan(at index: Int, with scan: UninstallScan) {
        pendingScans[index].resume(returning: scan)
    }

    func prepareForUninstall() async {}

    func uninstall(options: UninstallOptions) async throws -> UninstallResult {
        UninstallResult(removedTargetIDs: [], failures: [], applicationMovedToTrash: false)
    }
}
