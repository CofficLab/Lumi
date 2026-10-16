import XCTest
import AppKit

/// 模型选择器「刷新模型列表」UI 测试。
///
/// 复现用户报告：MiniMax 供应商默认显示 6 个模型；点击刷新后磁盘
/// models.json 已写入 9 个，但界面仍显示 6 个。
///
/// 确定性：App 以 `--lumi-ui-testing` 启动时，MiniMax 插件装配桩网络，
/// 刷新固定返回 9 个模型（静态 6 个 + 新增 3 个），不依赖真实网络与
/// 用户 API Key（范式参照 Cisum 的 `--cisum-ui-testing` 夹具注入）。
///
/// 根因：App 实际使用的 `CustomLLMManager`（PluginLLMManager 插件替换了
/// 默认的 `DefaultLLMManager`）漏实现 `notifyModelsRefreshed`，调用落到
/// 协议扩展的空实现，`.modelsRefreshed` 事件从不广播，模型选择器的
/// `LLMProviderManagerBox` 收不到事件、快照停留在刷新前的 6 个。
/// 包内单元测试直接使用 `DefaultLLMManager`（实现正确），无法暴露该问题，
/// 只有驱动真实 App 装配的 UI 测试能复现。
final class LumiModelSelectorRefreshUITests: XCTestCase {
    private var app: XCUIApplication!

    private enum Identifiers {
        static let popover = "lumi.model-selector.popover"
        static let miniMaxRow = "lumi.model-selector.provider.minimax-tokenplan"
        static let newModelRow = "lumi.model-selector.model.MiniMax-M2.1"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // 先终止残留实例（与 LumiUITests 一致），避免复用 Background 旧进程。
        app.terminate()
        app.launchArguments += [
            "-ApplePersistenceIgnoreState", "YES",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            // MiniMax 刷新走桩网络（固定 9 模型），见 MiniMaxUITestingSupport。
            "--lumi-ui-testing",
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        try super.tearDownWithError()
    }

    private func element(identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// 等待 MiniMax 供应商行的聚合无障碍标签包含指定片段（如 "6 models"）。
    @discardableResult
    private func waitForMiniMaxRowLabel(containing fragment: String, timeout: TimeInterval) -> Bool {
        let row = element(identifier: Identifiers.miniMaxRow)
        let predicate = NSPredicate(format: "label CONTAINS %@", fragment)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: row)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    func testMiniMaxModelCountUpdatesAfterRefresh() throws {
        XCTAssertTrue(
            element(identifier: "root.main").waitForExistence(timeout: 30),
            "主窗口未就绪"
        )

        // 打开模型选择弹窗。
        let selectModelButton = app.buttons["Select Model"]
        XCTAssertTrue(selectModelButton.waitForExistence(timeout: 15), "Action Bar 缺少模型选择按钮")
        selectModelButton.click()
        XCTAssertTrue(
            element(identifier: Identifiers.popover).waitForExistence(timeout: 10),
            "模型选择弹窗未出现"
        )

        // 切到「云端」页签（macOS 上分段 Picker 暴露为 RadioGroup），
        // 避免「常用」页签因使用记录不同导致 MiniMax 不一定出现。
        let cloudSegment = app.radioButtons["Cloud"]
        XCTAssertTrue(cloudSegment.waitForExistence(timeout: 5), "供应商列表缺少 Cloud 页签")
        cloudSegment.click()

        // 选中 MiniMax 供应商。
        let miniMaxRow = element(identifier: Identifiers.miniMaxRow)
        XCTAssertTrue(miniMaxRow.waitForExistence(timeout: 5), "云端供应商列表缺少 MiniMax")
        miniMaxRow.click()

        // 刷新前：静态清单 6 个模型。
        XCTAssertTrue(
            waitForMiniMaxRowLabel(containing: "6 models", timeout: 5),
            "刷新前 MiniMax 供应商行应显示 6 models"
        )

        // 点击右侧模型列表顶部的刷新按钮。
        let refreshButton = app.buttons["Refresh Models"]
        XCTAssertTrue(refreshButton.waitForExistence(timeout: 5), "模型列表缺少刷新按钮")
        refreshButton.click()

        // 核心断言：刷新成功后界面必须从 6 models 更新为 9 models。
        // 缺陷版本中刷新链路成功落盘但 .modelsRefreshed 事件未广播，
        // box 快照不刷新，界面一直停留在 6 models，本断言超时失败。
        XCTAssertTrue(
            waitForMiniMaxRowLabel(containing: "9 models", timeout: 20),
            "刷新后 MiniMax 供应商行应显示 9 models，实际仍为旧值"
        )
        XCTAssertFalse(
            waitForMiniMaxRowLabel(containing: "6 models", timeout: 1),
            "刷新后不应再显示 6 models"
        )

        // 新增模型应出现在右侧模型列表：模型数达到阈值（>8）后出现搜索框，
        // 用搜索过滤避免 LazyVStack 懒加载行未物化。
        let searchField = app.textFields.matching(
            NSPredicate(format: "placeholderValue == %@", "Search models")
        ).firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "模型列表缺少搜索框（模型数达到阈值后应显示）")
        // 用剪贴板而不是 typeText：后者逐字符合成按键，会被宿主输入法吞掉
        // 尾部字符，搜不到目标模型（详见 `LumiUITestCase` 的实测对照表）。
        // 本类继承的是 XCTestCase 而非 LumiUITestCase，因此这里内联粘贴。
        searchField.click()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("MiniMax-M2.1", forType: .string)
        sleep(1)
        searchField.typeKey("v", modifierFlags: .command)
        sleep(1)

        let newModelRow = element(identifier: Identifiers.newModelRow)
        XCTAssertTrue(
            newModelRow.waitForExistence(timeout: 5),
            "远程新增模型 MiniMax-M2.1 未出现在模型列表"
        )
    }
}
