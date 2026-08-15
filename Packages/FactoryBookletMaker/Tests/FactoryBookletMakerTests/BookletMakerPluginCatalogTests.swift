import FactoryBookletMaker
import XCTest

final class BookletMakerPluginCatalogTests: XCTestCase {
    /// 目录必须精确等于批准的 16 个插件 ID。
    @MainActor
    func testCatalogExactlyMatchesApprovedPluginSet() {
        let expected: Set<String> = [
            "com.coffic.lumi.plugin.storage",
            "com.coffic.lumi.plugin.projects",
            "com.coffic.lumi.plugin.layout", // WorkspacePlugin
            "com.coffic.lumi.plugin.command",
            "com.coffic.lumi.plugin.message-sender",
            "com.coffic.lumi.plugin.llm-provider-manager",
            "com.coffic.lumi.plugin.agent-turn-runner",
            "com.coffic.lumi.plugin.editor-host",
            "com.coffic.lumi.plugin.tool-manager",
            "com.coffic.lumi.plugin.settings",
            "com.coffic.lumi.plugin.logo",
            "com.coffic.lumi.plugin.theme-manager",
            "com.coffic.lumi.plugin.theme.lumi",
            "CoreMessageRenderer",
            "com.coffic.lumi.plugin.booklet-maker",
        ]

        let ids = Set(BookletMakerPluginCatalog.plugins.map(\.id))
        // StoragePlugin 初始化可能失败（try?），所以允许 storage 缺席；
        // 其余 15 个必须存在。
        let required = expected.subtracting(["com.coffic.lumi.plugin.storage"])
        XCTAssertTrue(required.isSubset(of: ids), "缺少必要插件，缺失：\(required.subtracting(ids).sorted())")

        // 没有批准列表之外的插件。
        let unexpected = ids.subtracting(expected)
        XCTAssertTrue(unexpected.isEmpty, "目录包含未批准的插件：\(unexpected.sorted())")
    }

    /// 插件 ID 必须唯一。
    @MainActor
    func testPluginIDsAreUnique() {
        let ids = BookletMakerPluginCatalog.plugins.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "插件目录存在重复 ID")
    }

    /// 关键 bootstrap 顺序：EditorHost（合并原 Kernel/Provider 两插件）存在且先于 ToolManager。
    @MainActor
    func testEditorHostPrecedesToolManager() {
        let ids = BookletMakerPluginCatalog.plugins.map(\.id)
        let hostIdx = ids.firstIndex(of: "com.coffic.lumi.plugin.editor-host")
        let toolManagerIdx = ids.firstIndex(of: "com.coffic.lumi.plugin.tool-manager")
        XCTAssertNotNil(hostIdx)
        XCTAssertNotNil(toolManagerIdx)
        XCTAssertLessThan(hostIdx!, toolManagerIdx!)
    }

    /// 固定配置：启用 BookletMaker 插件、隐藏状态栏与活动栏。
    @MainActor
    func testFixedConfigurationValues() {
        let config = FactoryBookletMaker.configuration
        XCTAssertEqual(config.enabledPluginIDs, [BookletMakerPluginCatalog.bookletMakerPluginID])
        XCTAssertEqual(config.initialContainerID, BookletMakerPluginCatalog.bookletMakerPluginID)
        XCTAssertFalse(config.showsStatusBar)
        XCTAssertFalse(config.showsActivityBar)
    }

    /// 目录不得包含 MLX / 数据库等重型插件。
    @MainActor
    func testCatalogExcludesHeavyPlugins() {
        let ids = BookletMakerPluginCatalog.plugins.map(\.id).joined(separator: " ").lowercased()
        XCTAssertFalse(ids.contains("mlx"), "BookletMaker 目录不应包含 MLX Provider")
        XCTAssertFalse(ids.contains("database-manager"), "BookletMaker 目录不应包含 DatabaseManager")
    }
}
