import FactoryLumi
import XCTest

final class LumiPluginCatalogTests: XCTestCase {
    /// 目录中的插件 ID 必须唯一。
    @MainActor
    func testPluginIDsAreUnique() {
        let ids = LumiPluginCatalog.plugins.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "插件目录存在重复 ID")
    }

    /// 关键 bootstrap 顺序：LLM Provider 管理器、编辑器宿主
    /// 必须先于依赖它们的插件（EditorPanelPlugin 等）注册。
    @MainActor
    func testCriticalBootstrapOrder() {
        let ids = LumiPluginCatalog.plugins.map(\.id)
        let managerIdx = ids.firstIndex(of: "com.coffic.lumi.plugin.llm-provider-manager")
        let editorHostIdx = ids.firstIndex(of: "com.coffic.lumi.plugin.editor-host")
        let editorPanelIdx = ids.firstIndex(of: "LumiEditor")

        XCTAssertNotNil(managerIdx)
        XCTAssertNotNil(editorHostIdx)
        XCTAssertNotNil(editorPanelIdx)

        // EditorHost（OnBoot 注册 EditorService）必须先于 EditorPanel。
        XCTAssertLessThan(managerIdx!, editorHostIdx!)
        XCTAssertLessThan(editorHostIdx!, editorPanelIdx!)
    }

    /// 代表性核心插件与功能插件 ID 必须存在。
    @MainActor
    func testRepresentativePluginIDsPresent() {
        let ids = Set(LumiPluginCatalog.plugins.map(\.id))
        for required in [
            "com.coffic.lumi.plugin.storage",
            "com.coffic.lumi.plugin.projects",
            "com.coffic.lumi.plugin.theme-manager",
            "com.coffic.lumi.plugin.booklet-maker",
        ] {
            XCTAssertTrue(ids.contains(required), "缺少必要插件 ID：\(required)")
        }
    }

    /// 目录应包含全部 LLM Provider，证明 FactoryLumi 是完整组合。
    @MainActor
    func testContainsMLXProvider() {
        let ids = LumiPluginCatalog.plugins.map(\.id)
        // LLMProviderMLXPlugin 是体积大头之一，验证它确实在完整目录里
        // （对比 FactoryBookletMaker 不应包含它）。
        XCTAssertTrue(ids.contains { $0.contains("mlx") || $0.contains("MLX") },
                      "完整目录应包含 MLX Provider")
    }

    /// 过渡 ID 选择 API：未知 ID 应抛错。
    @MainActor
    func testIDSelectionRejectsUnknownIDs() {
        XCTAssertThrowsError(
            try FactoryLumi.configuration(allowingIDs: ["__does_not_exist__"])
        )
    }

    /// 过渡 ID 选择 API：合法白名单应返回仅含白名单插件的配置。
    @MainActor
    func testIDSelectionFiltersToAllowlist() throws {
        let allowlist: Set<String> = [
            "com.coffic.lumi.plugin.storage",
            "com.coffic.lumi.plugin.projects",
        ]
        let config = try FactoryLumi.configuration(allowingIDs: allowlist)
        let ids = Set(config.plugins.map(\.id))
        XCTAssertEqual(ids, allowlist)
    }
}
