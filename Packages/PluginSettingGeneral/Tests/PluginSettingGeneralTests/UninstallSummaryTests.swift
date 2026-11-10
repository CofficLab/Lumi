import Foundation
import ProviderUninstall
import Testing
@testable import PluginSettingGeneral

/// 卸载确认汇总必须与执行时的过滤规则一致（Issue #1072）。
///
/// 关闭「移到废纸篓」或「删除 Keychain 凭据」后，汇总仍把它们计为待处理，
/// 用户无法确认自己实际批准了哪些删除动作。
@Suite("卸载确认汇总的有效范围")
struct UninstallSummaryTests {

    @Test("两个开关都打开时保留全部扫描结果")
    func defaultsKeepEveryTarget() {
        let scan = makeScan()

        let summary = UninstallSummary(
            scan: scan,
            removeApplication: true,
            removeKeychainCredentials: true
        )

        #expect(summary.targets.count == scan.targets.count)
        #expect(summary.totalSizeInBytes == scan.totalSizeInBytes)
    }

    @Test("关闭应用开关后不再计入应用及其体积")
    func applicationToggleOffExcludesApplication() {
        let scan = makeScan()

        let summary = UninstallSummary(
            scan: scan,
            removeApplication: false,
            removeKeychainCredentials: true
        )

        #expect(summary.targets.contains { $0.kind == .application } == false)
        #expect(summary.targets.contains { $0.kind == .keychain })
        #expect(summary.totalSizeInBytes == scan.totalSizeInBytes - 1_000)
    }

    @Test("关闭凭据开关后不再计入 Keychain 项目")
    func keychainToggleOffExcludesCredentials() {
        let scan = makeScan()

        let summary = UninstallSummary(
            scan: scan,
            removeApplication: true,
            removeKeychainCredentials: false
        )

        #expect(summary.targets.contains { $0.kind == .keychain } == false)
        #expect(summary.targets.contains { $0.kind == .application })
        #expect(summary.totalSizeInBytes == scan.totalSizeInBytes - 200)
    }

    @Test("两个开关都关闭时只保留总会清理的 Lumi 数据")
    func bothTogglesOffLeavesOnlyOwnedData() {
        let scan = makeScan()

        let summary = UninstallSummary(
            scan: scan,
            removeApplication: false,
            removeKeychainCredentials: false
        )

        #expect(summary.targets.map(\.kind) == [.applicationData, .caches])
        #expect(summary.totalSizeInBytes == 3_000)
    }

    @Test("扫描结果全部被排除时汇总为空")
    func everythingExcludedYieldsEmptySummary() {
        let scan = UninstallScan(targets: [
            makeTarget(kind: .application, id: "app", size: 1_000),
            makeTarget(kind: .keychain, id: "keychain", size: 200)
        ])

        let summary = UninstallSummary(
            scan: scan,
            removeApplication: false,
            removeKeychainCredentials: false
        )

        #expect(summary.targets.isEmpty)
        #expect(summary.totalSizeInBytes == 0)
    }

    private func makeScan() -> UninstallScan {
        UninstallScan(targets: [
            makeTarget(kind: .applicationData, id: "data", size: 2_000),
            makeTarget(kind: .caches, id: "caches", size: 1_000),
            makeTarget(kind: .application, id: "app", size: 1_000),
            makeTarget(kind: .keychain, id: "keychain", size: 200)
        ])
    }

    private func makeTarget(kind: UninstallTargetKind, id: String, size: Int64) -> UninstallTarget {
        UninstallTarget(id: id, kind: kind, location: "/tmp/\(id)", sizeInBytes: size)
    }
}
