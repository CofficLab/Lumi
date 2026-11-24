import Foundation
import Testing
@testable import PluginAppStoreConnect

/// 回归覆盖 issue #436：`saveMetadata` 曾在 await 之后无条件把响应写入
/// `editedLocalization` 并清除 `metadataIsDirty`。保存期间切换本地化或
/// 继续编辑时，迟到的响应会覆盖新内容、误报「已保存」。
///
/// 修复后响应落盘走 `applyMetadataSaveResponse`：只有仍在编辑同一条且
/// 编辑代次未变（期间无 `markMetadataDirty` / `selectLocalization`）才
/// 替换编辑态并清脏；列表刷新不受影响。
@Suite(.serialized)
struct VMMetadataSaveTests {

    @MainActor
    private func makeViewModel() -> VM {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VMMetadataSaveTests-\(UUID().uuidString)", isDirectory: true)
        return VM(localStore: AppStoreConnectPluginLocalStore(pluginDirectory: directory))
    }

    @MainActor
    private func makeLocalization(
        id: String,
        locale: String,
        description: String = ""
    ) -> AppStoreVersionLocalization {
        AppStoreVersionLocalization(
            id: id,
            locale: locale,
            promotionalText: "",
            description: description,
            keywords: "",
            whatsNew: "",
            supportURL: "",
            marketingURL: ""
        )
    }

    /// 复现 issue 场景：保存 A 期间切到 B 并编辑 B，A 的迟到响应不得
    /// 覆盖 B 的编辑态、不得清掉 B 的未保存标记。
    @Test("迟到的保存响应不覆盖已切换的本地化编辑（回归 #436）")
    @MainActor
    func staleResponseDoesNotClobberSwitchedLocalization() {
        let viewModel = makeViewModel()
        viewModel.localizations = [
            makeLocalization(id: "loc-a", locale: "en-US", description: "A original"),
            makeLocalization(id: "loc-b", locale: "zh-Hans", description: "B original"),
        ]
        viewModel.selectedLocalizationID = "loc-a"
        viewModel.editedLocalization = viewModel.localizations[0]
        let generationAtSaveStart = viewModel.metadataEditGeneration

        // 保存 pending 期间：切到 B 并编辑。
        viewModel.selectLocalization(id: "loc-b")
        viewModel.editedLocalization?.description = "B edited locally"
        viewModel.markMetadataDirty()

        let updatedA = makeLocalization(id: "loc-a", locale: "en-US", description: "A saved")
        viewModel.applyMetadataSaveResponse(updatedA, forEditGeneration: generationAtSaveStart)

        #expect(viewModel.selectedLocalizationID == "loc-b")
        #expect(viewModel.editedLocalization?.id == "loc-b")
        #expect(viewModel.editedLocalization?.description == "B edited locally", "B 的本地编辑不得被 A 的响应覆盖")
        #expect(viewModel.metadataIsDirty, "B 的未保存标记不得被 A 的响应清除")
        #expect(viewModel.localizations[0].description == "A saved", "响应仍应刷新列表里对应条目")
    }

    /// 保存同一条期间用户继续输入：编辑代次已变，响应不得替换编辑内容
    /// 也不得清脏（当前内容与服务器不一致，仍属未保存）。
    @Test("保存期间继续编辑时不替换编辑内容且保持未保存标记（回归 #436）")
    @MainActor
    func continuedEditDuringSaveKeepsLocalEditsAndDirtyMarker() {
        let viewModel = makeViewModel()
        viewModel.localizations = [makeLocalization(id: "loc-a", locale: "en-US", description: "A original")]
        viewModel.selectedLocalizationID = "loc-a"
        viewModel.editedLocalization = viewModel.localizations[0]
        let generationAtSaveStart = viewModel.metadataEditGeneration

        // 保存 pending 期间用户继续输入。
        viewModel.editedLocalization?.description = "A edited further during save"
        viewModel.markMetadataDirty()

        let updatedA = makeLocalization(id: "loc-a", locale: "en-US", description: "A saved")
        viewModel.applyMetadataSaveResponse(updatedA, forEditGeneration: generationAtSaveStart)

        #expect(viewModel.editedLocalization?.description == "A edited further during save")
        #expect(viewModel.metadataIsDirty)
        #expect(viewModel.localizations[0].description == "A saved")
    }

    @Test("无并发编辑时保存响应正常落盘并清除未保存标记（回归 #436）")
    @MainActor
    func responseAppliesWhenEditGenerationUnchanged() {
        let viewModel = makeViewModel()
        viewModel.localizations = [makeLocalization(id: "loc-a", locale: "en-US", description: "A original")]
        viewModel.selectedLocalizationID = "loc-a"
        viewModel.editedLocalization = viewModel.localizations[0]
        viewModel.markMetadataDirty()
        let generationAtSaveStart = viewModel.metadataEditGeneration

        let updatedA = makeLocalization(id: "loc-a", locale: "en-US", description: "A saved")
        viewModel.applyMetadataSaveResponse(updatedA, forEditGeneration: generationAtSaveStart)

        #expect(viewModel.editedLocalization?.description == "A saved")
        #expect(viewModel.metadataIsDirty == false)
        #expect(viewModel.localizations[0].description == "A saved")
    }
}
