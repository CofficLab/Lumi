import Foundation
import Testing
@testable import AppManagerPlugin

/// Regression coverage for #1221: a refresh publishes the enumerated app list
/// immediately, but `isLoading` used to stay true until every sequential
/// recursive size calculation finished. `AppRailView` hides the whole list
/// behind a blocking overlay while `isLoading` is true, so already-ready apps
/// were invisible/unselectable for the entire sizing period.
///
/// The fix ends `isLoading` as soon as `installedApps` is published and tracks
/// sizing with a separate, identity-guarded `isCalculatingSizes` state. These
/// tests gate enumeration/sizing on actors so the intermediate state is
/// observed deterministically (no reliance on the Combine search debounce).
@MainActor
struct AppListAvailabilityTests {

    @Test
    func listLoadingEndsWhenAppsPublishedWhileSizingContinues() async throws {
        let sizeGate = ScanGate()
        let alpha = Self.app(path: "/Applications/Alpha.app", name: "Alpha", size: 0)
        let beta = Self.app(path: "/Applications/Beta.app", name: "Beta", size: 0)
        let service = GatedAppService(
            appsByForce: [true: [alpha, beta]],
            sizeGates: [alpha.bundleURL.path: sizeGate, beta.bundleURL.path: sizeGate],
            sizedResults: [alpha.bundleURL.path: 4096, beta.bundleURL.path: 8192]
        )
        let viewModel = AppManagerViewModel(appService: service)

        let scan = Task { await viewModel.scanApps(force: true) }

        // 枚举完成、列表发布后，阻塞态必须立即结束——即使大小仍在后台计算。
        try await Self.waitFor { !viewModel.isLoading && viewModel.installedApps.count == 2 }
        #expect(viewModel.isLoading == false)
        #expect(viewModel.isCalculatingSizes == true)
        #expect(viewModel.installedApps.map(\.displayName) == ["Alpha", "Beta"])

        // 门闩仍挂起大小计算：列表数据已就绪，用户此刻即可看到并选择应用。
        #expect(viewModel.isCalculatingSizes == true)
        #expect(viewModel.installedApps.map(\.size) == [0, 0])

        await sizeGate.release()
        await scan.value

        #expect(viewModel.isLoading == false)
        #expect(viewModel.isCalculatingSizes == false)
        #expect(viewModel.installedApps.map(\.size) == [4096, 8192])
    }

    @Test
    func initialEnumerationKeepsBlockingLoadingUntilAppsPublished() async throws {
        let enumGate = ScanGate()
        let sizeGate = ScanGate()
        let alpha = Self.app(path: "/Applications/Alpha.app", name: "Alpha", size: 0)
        let service = GatedAppService(
            appsByForce: [true: [alpha]],
            enumerationGates: [true: enumGate],
            sizeGates: [alpha.bundleURL.path: sizeGate],
            sizedResults: [alpha.bundleURL.path: 4096]
        )
        let viewModel = AppManagerViewModel(appService: service)

        let scan = Task { await viewModel.scanApps(force: true) }

        // 初始枚举尚未完成：仍须显示阻塞 overlay，列表未发布，也未进入大小计算。
        try await Self.waitFor { viewModel.isLoading }
        #expect(viewModel.isLoading == true)
        #expect(viewModel.installedApps.isEmpty)
        #expect(viewModel.isCalculatingSizes == false)

        await enumGate.release()
        try await Self.waitFor { !viewModel.isLoading && viewModel.installedApps.count == 1 }
        #expect(viewModel.installedApps.map(\.displayName) == ["Alpha"])
        #expect(viewModel.isCalculatingSizes == true)

        await sizeGate.release()
        await scan.value
        #expect(viewModel.isLoading == false)
        #expect(viewModel.isCalculatingSizes == false)
        #expect(viewModel.installedApps.first?.size == 4096)
    }

    @Test
    func staleSizingCompletionDoesNotClobberNewerScanState() async throws {
        let staleEnumGate = ScanGate()
        let freshEnumGate = ScanGate()
        let staleSizeGate = ScanGate()
        let freshSizeGate = ScanGate()
        let stale = Self.app(path: "/Applications/Stale.app", name: "Stale", size: 0)
        let fresh = Self.app(path: "/Applications/Fresh.app", name: "Fresh", size: 0)
        let service = GatedAppService(
            appsByForce: [false: [stale], true: [fresh]],
            enumerationGates: [false: staleEnumGate, true: freshEnumGate],
            sizeGates: [stale.bundleURL.path: staleSizeGate, fresh.bundleURL.path: freshSizeGate],
            sizedResults: [stale.bundleURL.path: 100, fresh.bundleURL.path: 200]
        )
        let viewModel = AppManagerViewModel(appService: service)

        let staleScan = Task { await viewModel.scanApps(force: false) }
        await staleEnumGate.release()
        try await Self.waitFor { !viewModel.isLoading && viewModel.installedApps.map(\.displayName) == ["Stale"] }
        #expect(viewModel.isCalculatingSizes == true)

        // 新扫描取消旧扫描并接管状态；旧扫描的大小计算仍被门闩挂起。
        let freshScan = Task { await viewModel.scanApps(force: true) }
        try await Self.waitFor { viewModel.isLoading }
        await freshEnumGate.release()
        try await Self.waitFor { !viewModel.isLoading && viewModel.installedApps.map(\.displayName) == ["Fresh"] }
        #expect(viewModel.isCalculatingSizes == true)

        // 旧扫描的大小计算此刻才晚到完成：不得覆盖新扫描的列表/加载/计算状态。
        await staleSizeGate.release()
        try await Task.sleep(nanoseconds: 120_000_000)
        #expect(viewModel.installedApps.map(\.displayName) == ["Fresh"])
        #expect(viewModel.installedApps.first?.size == 0)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.isCalculatingSizes == true)

        await freshSizeGate.release()
        await staleScan.value
        await freshScan.value
        #expect(viewModel.isLoading == false)
        #expect(viewModel.isCalculatingSizes == false)
        #expect(viewModel.installedApps.map(\.displayName) == ["Fresh"])
        #expect(viewModel.installedApps.first?.size == 200)
    }

    // MARK: - Helpers

    private static func waitFor(_ condition: () -> Bool) async throws {
        for _ in 0..<400 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition())
    }

    private static func app(path: String, name: String, size: Int64) -> AppModel {
        AppModel(
            bundleURL: URL(fileURLWithPath: path),
            name: name,
            identifier: "com.example.\(name.lowercased())",
            version: "1.0",
            iconFileName: nil,
            size: size
        )
    }
}

/// 异步门闩：`wait()` 挂起直到 `release()`，用于确定性地构造「大小计算尚未完成」
/// 与「旧请求晚到」的中间态（Swift 6 下不在 async 闭包里用信号量阻塞）。
private actor ScanGate {
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var released = false

    func wait() async {
        if released { return }
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func release() {
        released = true
        let pending = continuations
        continuations.removeAll()
        for continuation in pending {
            continuation.resume()
        }
    }
}

/// 可按 force 路由枚举门闩、按 App 路径路由大小门闩的假服务。
private final class GatedAppService: AppManagerServicing, @unchecked Sendable {
    let appsByForce: [Bool: [AppModel]]
    let enumerationGates: [Bool: ScanGate]
    let sizeGates: [String: ScanGate]
    let sizedResults: [String: Int64]

    init(
        appsByForce: [Bool: [AppModel]],
        enumerationGates: [Bool: ScanGate] = [:],
        sizeGates: [String: ScanGate] = [:],
        sizedResults: [String: Int64] = [:]
    ) {
        self.appsByForce = appsByForce
        self.enumerationGates = enumerationGates
        self.sizeGates = sizeGates
        self.sizedResults = sizedResults
    }

    func scanInstalledApps(force: Bool) async -> [AppModel] {
        if let gate = enumerationGates[force] { await gate.wait() }
        return appsByForce[force] ?? []
    }

    func calculateAppSize(for app: AppModel) async -> Int64 {
        if let gate = sizeGates[app.bundleURL.path] { await gate.wait() }
        return sizedResults[app.bundleURL.path] ?? app.size
    }

    func scanRelatedFiles(for app: AppModel) async -> [RelatedFile] { [] }
    func deleteFiles(_ files: [RelatedFile]) async -> DeleteFilesResult {
        DeleteFilesResult(deleted: files, failed: [])
    }
    func saveCache() async {}
    func revealInFinder(_ app: AppModel) {}
    func openApp(_ app: AppModel) {}
    func getAppInfo(_ app: AppModel) -> String { app.displayName }
}

/// Regression coverage for #795: Refresh replaces `installedApps` with freshly
/// constructed `AppModel`s, each carrying a brand-new UUID `id`. The row
/// highlight compares `selectedApp?.id == app.id`, so without reconciliation the
/// highlight splits from the detail; and an app removed externally before the
/// refresh used to leave a stale detail / related files / action buttons behind.
///
/// The fix reconciles `selectedApp` by stable `bundleURL.path` after the new list
/// is published: remap to the new model when still present, clear the whole
/// selection/detail when gone. These tests drive two scans (force:false then
/// force:true) through `GatedAppService` so the "new batch" is deterministic.
@MainActor
struct AppSelectionReconciliationTests {

    @Test
    func refreshRemapsSelectionToNewModelByPath() async throws {
        let path = "/Applications/Alpha.app"
        let old = Self.app(path: path, name: "Alpha", size: 4096)
        let new = Self.app(path: path, name: "Alpha", size: 4096)
        #expect(old.id != new.id) // 每个模型 id 都是新 UUID
        let service = GatedAppService(appsByForce: [false: [old], true: [new]])
        let viewModel = AppManagerViewModel(appService: service)

        await viewModel.scanApps(force: false)
        viewModel.selectedApp = viewModel.installedApps[0]
        let oldID = viewModel.selectedApp?.id

        await viewModel.scanApps(force: true)

        // 选中项映射到新模型：行高亮（按 id 比较）恢复一致，详情读到新模型。
        #expect(viewModel.selectedApp != nil)
        #expect(viewModel.selectedApp?.bundleURL.path == path)
        #expect(viewModel.selectedApp?.id == viewModel.installedApps[0].id)
        #expect(viewModel.selectedApp?.id != oldID)
    }

    @Test
    func refreshClearsSelectionWhenAppRemovedExternally() async throws {
        let alpha = Self.app(path: "/Applications/Alpha.app", name: "Alpha", size: 4096)
        let service = GatedAppService(appsByForce: [false: [alpha], true: []])
        let viewModel = AppManagerViewModel(appService: service)

        await viewModel.scanApps(force: false)
        viewModel.selectedApp = viewModel.installedApps[0]
        let file = RelatedFile(path: "/Library/Application Support/Alpha", size: 10, type: .support)
        viewModel.relatedFiles = [file]
        viewModel.selectedFileIds = [file.id]
        viewModel.showUninstallConfirmation = true

        await viewModel.scanApps(force: true)

        // 应用已被外部移除：选择、详情、关联文件、待删除勾选与确认弹窗全部清空。
        #expect(viewModel.installedApps.isEmpty)
        #expect(viewModel.selectedApp == nil)
        #expect(viewModel.relatedFiles.isEmpty)
        #expect(viewModel.selectedFileIds.isEmpty)
        #expect(viewModel.showUninstallConfirmation == false)
        #expect(viewModel.isScanningFiles == false)
    }

    @Test
    func refreshClearsRemovedSelectionEvenWhenListNonEmpty() async throws {
        let alpha = Self.app(path: "/Applications/Alpha.app", name: "Alpha", size: 4096)
        let beta = Self.app(path: "/Applications/Beta.app", name: "Beta", size: 4096)
        let alphaNew = Self.app(path: "/Applications/Alpha.app", name: "Alpha", size: 4096)
        let service = GatedAppService(appsByForce: [false: [alpha, beta], true: [alphaNew]])
        let viewModel = AppManagerViewModel(appService: service)

        await viewModel.scanApps(force: false)
        viewModel.selectedApp = viewModel.installedApps[1] // 选中 Beta
        let file = RelatedFile(path: "/Library/Application Support/Beta", size: 10, type: .support)
        viewModel.relatedFiles = [file]
        viewModel.selectedFileIds = [file.id]

        await viewModel.scanApps(force: true)

        // Beta 被移除（列表仍非空）：选中与详情仍须清空，不得残留矛盾状态。
        #expect(viewModel.installedApps.map(\.bundleURL.path) == ["/Applications/Alpha.app"])
        #expect(viewModel.selectedApp == nil)
        #expect(viewModel.relatedFiles.isEmpty)
        #expect(viewModel.selectedFileIds.isEmpty)
    }

    @Test
    func refreshPreservesRelatedFilesWhenAppStillExists() async throws {
        let path = "/Applications/Alpha.app"
        let old = Self.app(path: path, name: "Alpha", size: 4096)
        let new = Self.app(path: path, name: "Alpha", size: 4096)
        let service = GatedAppService(appsByForce: [false: [old], true: [new]])
        let viewModel = AppManagerViewModel(appService: service)

        await viewModel.scanApps(force: false)
        viewModel.selectedApp = viewModel.installedApps[0]
        let file = RelatedFile(path: "/Library/Application Support/Alpha", size: 10, type: .support)
        viewModel.relatedFiles = [file]
        viewModel.selectedFileIds = [file.id]

        await viewModel.scanApps(force: true)

        // 应用仍在：仅 remap 选中项，关联文件与待删除勾选保持不变（不过度清空）。
        #expect(viewModel.selectedApp?.id == viewModel.installedApps[0].id)
        #expect(viewModel.relatedFiles.map(\.id) == [file.id])
        #expect(viewModel.selectedFileIds == [file.id])
    }

    // MARK: - Helpers

    private static func app(path: String, name: String, size: Int64) -> AppModel {
        AppModel(
            bundleURL: URL(fileURLWithPath: path),
            name: name,
            identifier: "com.example.\(name.lowercased())",
            version: "1.0",
            iconFileName: nil,
            size: size
        )
    }
}