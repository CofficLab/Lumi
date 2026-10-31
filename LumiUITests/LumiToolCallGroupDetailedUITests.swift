import XCTest
import AppKit

/// 消息列表 **V3（detailed）** 保持多工具调用逐条铺开的端到端 UI 测试。
///
/// ## 要验证的行为
///
/// 「多工具调用折叠为一行摘要」只发生在 **V2（standard）**。
/// V3（detailed）的定位是「展示更多细节」，因此必须**保持原来的逐条铺开效果**。
///
/// ## 为什么单独一个测试类
///
/// V3 与 V2 的**列表槽位互斥**（`exclusiveGroup: "message-list"`）：
/// V3 槽位只在「当前会话详细程度为 `.detailed`」时激活，而槽位激活靠
/// `ChatSectionProviding.refreshItems()`——它是**异步**的（Task + yield）。
///
/// 因此 `.detailed` 的会话必须种在 **V3 自己的夹具**里
/// （`--lumi-ui-testing-message-list-detailed`），且 App 必须用那个启动参数
/// 起来。把 `.detailed` 会话混进 V2 夹具再切过去，槽位激活会与刷新时序
/// 竞争，表现为偶发的 AX 超时——那测的是时序，不是被测行为。
///
/// ## 对照的有效性
///
/// V3 夹具里的工具调用组会话与 V2 夹具里的**内容完全相同**
/// （同样 3 个多调用 + 1 个单调用，同样「读取文件 / 搜索代码 / 运行测试」），
/// 唯一区别是回复级别。因此「V2 折叠 / V3 不折叠」的差异**只能**归因于级别。
///
/// ## 定位方式
///
/// 按**标识符 / 文案**定位，不按摘要行数量：AX 树里同一标识符可能匹配
/// 多个元素（SwiftUI 的 identifier 传播），拿它做等值断言得到的是快照噪声。
final class LumiToolCallGroupDetailedUITests: LumiUITestCase {

    /// 折叠态的无障碍标识符（复述 `ToolCallGroupAccessibility`）。
    private enum Identifiers {
        /// 折叠态摘要行。
        static let summaryRow = "lumi.tool-call-group.summary"
    }

    /// 工具调用行的标识符（按 **工具调用 id**，见 `ToolCallRowAccessibility`）。
    ///
    /// 不按文案定位：行内文案是本地化文本且会被 `lineLimit(1)` 截断。
    private enum ToolCalls {
        static let groupRowIDs = ["group-1", "group-2", "group-3"]
    }

    /// 首屏遮罩的稳定标识符（复述 `MessageLoadingView.identifier`）。
    private static let maskIdentifier = "lumi.message-list.loading-mask"

    /// 夹具植入的会话标题（V3 夹具）。
    private enum Conversations {
        static let toolGroup = "Detailed Tool Group Target"
    }

    // MARK: - Lifecycle

    override func setUpWithError() throws {
        continueAfterFailure = false
        launchLumi(extraArguments: [
            // 确定性 LLM 供应商 + 隔离存储 + **V3 夹具**
            //（种出 .detailed 会话，激活 V3 槽位）。
            //
            // - Important: `--lumi-ui-testing` 必须带上，它强制选中桩供应商
            //   `ui-test`（否则会拿到 UserDefaults 里残留的真实供应商）。
            //   夹具种入会话时会插入**用户消息**，`PluginAgentLoop.MessageObserver`
            //   因此会为每个会话自动跑一个回合；那 3 个回合的完成时刻各不相同，
            //   会把各会话的 `lastMessageAt` 推到「现在」并让会话列表顺序在
            //   run-to-run 之间摇摆。夹具已通过 `setAutoReplySuppressed` 阻断
            //   自动回合，但挂上桩供应商仍能保证「任何路径都不会打到真实供应商」。
            "--lumi-ui-testing",
            "--lumi-ui-testing-isolated-storage",
            "--lumi-ui-testing-message-list-detailed",
        ])
        waitForMainWindow()
    }

    override func tearDownWithError() throws {
        terminateAppAndWait()
        try super.tearDownWithError()
    }

    // MARK: - Tests

    /// V3（detailed）必须保持原来的逐条铺开效果：不折叠成摘要。
    func testDetailedVerbosityKeepsToolCallsExpanded() throws {
        switchConversation(to: Conversations.toolGroup)
        waitForLoadingMaskToClear()

        // 断言 1：确实切到了目标会话。
        //
        // 用**工具调用行的标识符**作锚点，而不是会话行的 `isSelected`
        // 或消息正文：`isSelected` 在列表行被 SwiftUI 重建时可能长时间不翻转，
        // 而消息正文可能被滚动出视口。工具调用行的标识符由夹具里的调用 id
        // 唯一确定，既稳定又直接对应被测行为。
        XCTAssertTrue(
            element(identifier: Self.rowIdentifier(ToolCalls.groupRowIDs[0]))
                .waitForExistence(timeout: 30),
            """
            未切换到目标会话（工具调用行「\(ToolCalls.groupRowIDs[0])」未出现）。\
            \(diagnostics())
            """
        )

        // 断言 2：V3 下三条工具调用**直接铺开**，无需任何交互。
        //
        // 若它们被折叠进了 popover，这些描述在 popover 未展开时必然不可见。
        for rowID in ToolCalls.groupRowIDs {
            XCTAssertTrue(
                element(identifier: Self.rowIdentifier(rowID)).waitForExistence(timeout: 10),
                """
                V3（detailed）下工具调用行「\(rowID)」未直接铺开。\
                V3 应保持原来的逐条展开效果，不折叠。\(diagnostics())
                """
            )
        }

        // 断言 3：V3 下不应出现折叠摘要行。
        XCTAssertFalse(
            element(identifier: Identifiers.summaryRow).exists,
            """
            V3（detailed）下出现了折叠摘要行。\
            折叠只应发生在 V2；V3 应保持原来的逐条展开效果。
            """
        )
    }

    // MARK: - Helpers

    /// 在会话列表里点击指定标题。
    ///
    /// - Note: 这里**不**等 `isSelected`。会话列表行被 SwiftUI 重建时，
    ///   AX 元素的 `isSelected` 可能长时间不翻转（实测会出现
    ///   「点击成功但选中态迟迟不来」），失败点会漂移到与被测行为无关的地方。
    ///   切换是否真的生效，由调用方用**该会话的内容锚点**判定——
    ///   那才是「确实切过去了」的直接证据。
    private func switchConversation(to title: String) {
        let row = conversationRow(title)
        XCTAssertTrue(
            row.waitForExistence(timeout: 15),
            "会话「\(title)」在列表中不可见（列表容器内未找到）"
        )
        row.click()
    }

    /// 定位一条会话行：限定列表容器 → 按 item 标识筛出所有行 → 按 label 匹配标题。
    private func conversationRow(_ title: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: LumiConversationListIDs.listID)
            .descendants(matching: .any)
            .matching(identifier: LumiConversationListIDs.itemID)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", title, title))
            .firstMatch
    }


    /// 工具调用行的标识符（复述 `ToolCallRowAccessibility`）。
    private static func rowIdentifier(_ toolCallID: String) -> String {
        "lumi.tool-call-row.\(toolCallID)"
    }

    /// 等首屏遮罩消失。
    ///
    /// - Important: 切到会话后**必须**等遮罩消失再断言内容。
    ///   遮罩期间消息区还没渲染，锚点自然查不到——此时断言「内容没出现」
    ///   测的是「遮罩还没撤」，不是被测行为。
    ///   （既有 `LumiMessageListSwitchUITests` 用同一条纪律。）
    ///
    ///   遮罩可能**从未出现**（切换太快），此时直接返回——
    ///   不能因为「没等到遮罩」就判失败。
    private func waitForLoadingMaskToClear(timeout: TimeInterval = 15) {
        let mask = element(identifier: Self.maskIdentifier)
        guard mask.waitForExistence(timeout: 2) else { return }
        _ = mask.waitForNonExistence(timeout: timeout)
    }

    /// 失败诊断用的占位文本。
    ///
    /// - Important: 刻意**不**在失败路径上查询 AX 树。
    ///
    ///   实测：`app.descendants(matching: .staticText).allElementsBoundByIndex`
    ///   这类全量快照在消息列表较大时会挂起数分钟，并在挂起后让后续查询
    ///   一并失败（AX 快照失效）。届时这个「诊断信息」会**顶替掉**真正的
    ///   断言失败信息，失败点从「行为不对」漂移成「诊断信息取不到」，
    ///   极难归因。
    ///
    ///   断言消息里已经写明了具体的锚点 / 描述 / 标识符，
    ///   这些信息足以定位问题，不需要再抓一遍界面文本。
    private func diagnostics() -> String {
        "<见断言消息中的锚点与标识符>"
    }
}
