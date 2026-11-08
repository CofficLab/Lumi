import Foundation
import Testing
@testable import PluginAppStoreConnect

/// 快速切换 App 时的选择上下文隔离。
///
/// 旧实现用全局 `isLoadingVersions` 防重入：A 的版本请求还在跑时切到 B，
/// B 的加载被直接挡回；随后 A 的结果无条件写入全局状态并继续加载
/// A 的本地化和发布信息，导致 B 的页面展示 A 的数据。
@Suite(.serialized)
struct VMAppSwitchTests {

    @MainActor
    private func makeViewModel() -> VM {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VMAppSwitchTests-\(UUID().uuidString)", isDirectory: true)
        // 版本请求会带出 ConnectAPICache，测试进程里必须先注入隔离目录。
        AppStoreConnectPluginRuntimeBridge.pluginSubdirectory = directory
        return VM(localStore: AppStoreConnectPluginLocalStore(pluginDirectory: directory))
    }

    private func makeApp(id: String) -> AppStoreApp {
        AppStoreApp(
            id: id,
            name: "App \(id)",
            bundleID: "com.example.\(id)",
            sku: "SKU-\(id)",
            primaryLocale: "en-US",
            platform: "IOS"
        )
    }

    private func makeVersion(id: String) -> AppStoreVersion {
        AppStoreVersion(
            id: id,
            platform: "IOS",
            versionString: "1.0",
            appStoreState: "PREPARE_FOR_SUBMISSION",
            appVersionState: "PREPARE_FOR_SUBMISSION",
            createdDate: nil
        )
    }

    @Test("切到别的 App 时，加载不会被上一 App 的进行中请求挡住")
    @MainActor
    func loadingAnotherAppIsNotSkipped() async {
        let viewModel = makeViewModel()
        let appA = makeApp(id: "app-a")
        let appB = makeApp(id: "app-b")

        viewModel.selectedApp = appB
        // 模拟 A 的版本请求仍在进行中。
        viewModel.isLoadingVersions = true
        viewModel.versionLoadAppID = appA.id

        await viewModel.loadVersions()

        // 旧实现会在这里被全局 isLoadingVersions 直接挡回，B 永远不会加载。
        // 新实现会真正发起 B 的加载，并在失败后清理自己的加载标记。
        #expect(!viewModel.isLoadingVersions)
        #expect(viewModel.versionLoadAppID == nil)
    }

    @Test("上一 App 迟到的版本结果不会写入当前选择")
    @MainActor
    func lateVersionsFromPreviousAppAreDiscarded() {
        let viewModel = makeViewModel()
        let appA = makeApp(id: "app-a")
        let appB = makeApp(id: "app-b")

        viewModel.selectApp(appA)
        let generationA = viewModel.selectionGeneration
        viewModel.selectApp(appB)

        let applied = viewModel.applyLoadedVersions(
            [makeVersion(id: "version-a")],
            for: appA.id,
            generation: generationA
        )

        #expect(!applied)
        #expect(viewModel.versions.isEmpty)
        #expect(viewModel.selectedVersion == nil)
    }

    @Test("当前 App 与代次的版本结果正常写入")
    @MainActor
    func currentVersionsAreApplied() {
        let viewModel = makeViewModel()
        let appA = makeApp(id: "app-a")

        viewModel.selectApp(appA)
        let generation = viewModel.selectionGeneration

        let applied = viewModel.applyLoadedVersions(
            [makeVersion(id: "version-a")],
            for: appA.id,
            generation: generation
        )

        #expect(applied)
        #expect(viewModel.versions.map(\.id) == ["version-a"])
        #expect(viewModel.selectedVersion?.id == "version-a")
    }

    @Test("账号切换后旧账号的 App 列表不得写入当前列表")
    @MainActor
    func lateAppsFromPreviousAccountAreDiscarded() {
        let viewModel = makeViewModel()
        let oldCredentials = viewModel.credentials
        let appliedForOldAccount = viewModel.applyLoadedApps(
            [makeApp(id: "app-a")],
            for: oldCredentials
        )
        #expect(appliedForOldAccount)
        #expect(viewModel.apps.map(\.id) == ["app-a"])

        viewModel.credentials = AppStoreConnectCredentials(
            issuerID: "new-issuer",
            keyID: "new-key",
            privateKey: "new-private-key"
        )

        let appliedAfterSwitch = viewModel.applyLoadedApps(
            [makeApp(id: "app-b")],
            for: oldCredentials
        )

        #expect(!appliedAfterSwitch)
        #expect(viewModel.apps.map(\.id) == ["app-a"])
    }
}
