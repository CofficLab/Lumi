import Foundation
import Testing
@testable import PluginAppStoreConnect

/// 截图列表刷新：内存字典只在普通切换展示类型时复用，强制刷新必须重新请求。
///
/// 上传/删除会把 `client.fetchPolicy` 切成 networkOnly，但 `loadScreenshots`
/// 先读 `screenshotsBySetID`，命中就直接返回旧列表，请求根本没发出去。
@Suite(.serialized)
struct VMScreenshotRefreshTests {

    @MainActor
    private func makeViewModel() -> VM {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VMScreenshotRefreshTests-\(UUID().uuidString)", isDirectory: true)
        // 截图请求会带出 ConnectAPICache，测试进程里必须先注入隔离目录。
        AppStoreConnectPluginRuntimeBridge.pluginSubdirectory = directory
        return VM(localStore: AppStoreConnectPluginLocalStore(pluginDirectory: directory))
    }

    @MainActor
    private func seedStaleScreenshot(_ viewModel: VM) -> AppScreenshot {
        let set = ScreenshotSet(id: "set-1", screenshotDisplayType: "APP_IPHONE_67")
        let stale = AppScreenshot(id: "shot-old", fileName: "old.png")
        viewModel.screenshotSets = [set]
        viewModel.selectedScreenshotDisplayType = set.screenshotDisplayType
        viewModel.screenshotsBySetID = [set.id: [stale]]
        viewModel.screenshots = [stale]
        return stale
    }

    @Test("强制刷新截图时绕过内存字典")
    @MainActor
    func forceRefreshBypassesScreenshotDictionary() async {
        let viewModel = makeViewModel()
        _ = seedStaleScreenshot(viewModel)

        await viewModel.reloadScreenshotsForSelectedDisplayType(forceRefresh: true)

        // 这条路径必须真的发请求：测试用的 VM 没有网络传输，请求失败会写入错误。
        // 若仍命中内存字典，就会静默返回旧列表、errorMessage 保持为 nil。
        #expect(viewModel.errorMessage != nil)
    }

    @Test("普通切换展示类型时复用内存字典")
    @MainActor
    func regularReloadReusesScreenshotDictionary() async {
        let viewModel = makeViewModel()
        let stale = seedStaleScreenshot(viewModel)

        await viewModel.reloadScreenshotsForSelectedDisplayType()

        // 正常切换不应触发请求，直接展示缓存，且不产生错误。
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.screenshots.map(\.id) == [stale.id])
    }
}
