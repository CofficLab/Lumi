import Foundation
import Testing
@testable import PluginAppStoreConnect

/// 回归覆盖 issue #435：切换版本/本地化后，迟到的旧响应不得覆盖新选择。
///
/// 各加载流程统一把「await 之后写共享状态」收敛为带身份校验的 apply
/// 函数（`applyLoadedLocalizations` / `applyScreenshotPayload` /
/// `applyLoadedScreenshots`），这里同步驱动这些函数复现「旧请求晚到」。
@Suite(.serialized)
struct VMVersionSwitchStaleTests {

    @MainActor
    private func makeViewModel() -> VM {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VMVersionSwitchStaleTests-\(UUID().uuidString)", isDirectory: true)
        // VM 构造会带出 ConnectAPICache，测试进程里必须先注入隔离目录。
        AppStoreConnectPluginRuntimeBridge.pluginSubdirectory = directory
        return VM(localStore: AppStoreConnectPluginLocalStore(pluginDirectory: directory))
    }

    @MainActor
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

    @MainActor
    private func makeLocalization(id: String, locale: String) -> AppStoreVersionLocalization {
        AppStoreVersionLocalization(
            id: id,
            locale: locale,
            promotionalText: "",
            description: "",
            keywords: "",
            whatsNew: "",
            supportURL: "",
            marketingURL: ""
        )
    }

    // MARK: - 本地化

    /// 版本 A 的本地化响应在已切到版本 B 之后到达：不覆盖 B 的列表与选择。
    @Test("迟到的本地化响应不覆盖已切换的版本（回归 #435）")
    @MainActor
    func staleLocalizationsDoNotClobberSwitchedVersion() {
        let viewModel = makeViewModel()
        let versionB = makeVersion(id: "ver-b")
        viewModel.selectedVersion = versionB
        viewModel.localizations = [makeLocalization(id: "loc-b", locale: "zh-Hans")]
        viewModel.selectedLocalizationID = "loc-b"
        viewModel.editedLocalization = viewModel.localizations[0]

        let staleA = [makeLocalization(id: "loc-a", locale: "en-US")]
        let applied = viewModel.applyLoadedLocalizations(
            staleA,
            forVersionID: "ver-a",
            preferredLocalizationID: nil
        )

        #expect(!applied)
        #expect(viewModel.localizations.map(\.id) == ["loc-b"], "B 的本地化列表不得被 A 的响应覆盖")
        #expect(viewModel.selectedLocalizationID == "loc-b")
        #expect(viewModel.editedLocalization?.id == "loc-b")
    }

    /// 版本匹配时正常落盘：写入列表并按偏好/主语言/首条挑当前本地化。
    @Test("版本匹配的本地化响应正常落盘并选中（回归 #435）")
    @MainActor
    func matchingLocalizationsApplyAndSelect() {
        let viewModel = makeViewModel()
        let versionB = makeVersion(id: "ver-b")
        viewModel.selectedVersion = versionB

        let fetched = [
            makeLocalization(id: "loc-en", locale: "en-US"),
            makeLocalization(id: "loc-zh", locale: "zh-Hans"),
        ]
        let applied = viewModel.applyLoadedLocalizations(
            fetched,
            forVersionID: "ver-b",
            preferredLocalizationID: nil
        )

        #expect(applied)
        #expect(viewModel.localizations.count == 2)
        #expect(viewModel.selectedLocalizationID == "loc-en", "主语言 en-US 应被选中")
        #expect(viewModel.editedLocalization?.id == "loc-en")
        #expect(!viewModel.metadataIsDirty)

        // 再次落盘时保留用户已选中的本地化。
        _ = viewModel.applyLoadedLocalizations(
            fetched,
            forVersionID: "ver-b",
            preferredLocalizationID: "loc-zh"
        )
        #expect(viewModel.selectedLocalizationID == "loc-zh")
    }

    // MARK: - 截图集合

    /// 本地化 A 的截图集合负载在已切到本地化 B 之后到达：不写任何状态。
    @Test("迟到的截图集合负载不覆盖已切换的本地化（回归 #435）")
    @MainActor
    func staleScreenshotPayloadDoesNotClobberSwitchedLocalization() async throws {
        let viewModel = makeViewModel()
        let setB = ScreenshotSet(id: "set-b", screenshotDisplayType: "APP_IPHONE_67")
        viewModel.screenshotSets = [setB]
        viewModel.selectedScreenshotDisplayType = setB.screenshotDisplayType
        viewModel.selectedLocalizationID = "loc-b"
        let beforeSets = viewModel.screenshotSets

        let stalePayload = ScreenshotSetsPayload(
            sets: [ScreenshotSet(id: "set-a", screenshotDisplayType: "APP_IPAD_PRO_129")],
            screenshotsBySetID: ["set-a": [AppScreenshot(id: "shot-a", fileName: "a.png")]]
        )
        try await viewModel.applyScreenshotPayload(stalePayload, expectedLocalizationID: "loc-a")

        // 同步断言：丢弃分支必须完全不写状态。
        #expect(viewModel.screenshotSets == beforeSets)
        #expect(viewModel.screenshotsBySetID.isEmpty, "A 的截图缓存不得写入")
    }

    /// 本地化匹配时正常落盘：写入集合并按展示类型对齐当前 set。
    @Test("本地化匹配的截图集合负载正常落盘（回归 #435）")
    @MainActor
    func matchingScreenshotPayloadApplies() async throws {
        let viewModel = makeViewModel()
        viewModel.selectedLocalizationID = "loc-a"

        let payload = ScreenshotSetsPayload(
            sets: [
                ScreenshotSet(id: "set-6", screenshotDisplayType: "APP_IPHONE_67"),
                ScreenshotSet(id: "set-pad", screenshotDisplayType: "APP_IPAD_PRO_129"),
            ],
            screenshotsBySetID: [
                "set-6": [AppScreenshot(id: "shot-6", fileName: "6.png")],
            ]
        )
        try await viewModel.applyScreenshotPayload(payload, expectedLocalizationID: "loc-a")

        #expect(viewModel.screenshotSets.count == 2)
        #expect(viewModel.screenshots.map(\.id) == ["shot-6"], "默认展示类型对齐后应展示 6.7 寸列表")
    }

    // MARK: - 截图列表

    /// set 加载 await 期间切到其它展示类型：旧 set 的列表只进缓存，不覆盖展示。
    @Test("迟到 set 列表只进缓存不覆盖当前展示（回归 #435）")
    @MainActor
    func staleSetListOnlyUpdatesCache() {
        let viewModel = makeViewModel()
        let setA = ScreenshotSet(id: "set-a", screenshotDisplayType: "APP_IPAD_PRO_129")
        let setB = ScreenshotSet(id: "set-b", screenshotDisplayType: "APP_IPHONE_67")
        viewModel.screenshotSets = [setA, setB]
        viewModel.selectedScreenshotDisplayType = setB.screenshotDisplayType
        let displayed = AppScreenshot(id: "shot-b", fileName: "b.png")
        viewModel.screenshots = [displayed]

        let staleList = [AppScreenshot(id: "shot-a", fileName: "a.png")]
        let applied = viewModel.applyLoadedScreenshots(staleList, forSetID: "set-a")

        #expect(!applied)
        #expect(viewModel.screenshotsBySetID["set-a"]?.map(\.id) == ["shot-a"], "缓存仍按 set 正确记录")
        #expect(viewModel.screenshots.map(\.id) == ["shot-b"], "当前展示不得被旧 set 覆盖")

        let freshList = [AppScreenshot(id: "shot-b2", fileName: "b2.png")]
        let appliedFresh = viewModel.applyLoadedScreenshots(freshList, forSetID: "set-b")

        #expect(appliedFresh)
        #expect(viewModel.screenshots.map(\.id) == ["shot-b2"])
    }
}
