import XCTest
import AppKit

/// 消息列表 V2「多工具调用折叠为一行摘要」的端到端 UI 测试。
///
/// ## 要验证的行为
///
/// 一条助手消息里包含**多个连续工具调用**时，V2 应当把它们**合并成一行摘要**
/// （「执行了 N 个步骤 · 耗时」），点击后在 popover 里逐条展开。
/// 单个工具调用**不折叠**，仍逐条铺开——折叠给单个调用平白加了一层间接。
///
/// ## 为什么单元测试不够
///
/// 折叠判定本身是纯逻辑（`ToolCallGroupCollapsePolicy`），单元测试已经锁住。
/// 但这条链路还有两段只有真实进程才能验：
///
/// 1. **数据层合成**：`MessageListRowBuilder` 把连续多条「只含工具调用的助手消息」
///    合并成一条 `turn-activity` 合成消息；
/// 2. **渲染层分发**：`core-tool-step-group` 渲染器拿到合成消息后，摘要行与
///    popover 是否真的画出来、popover 里是否真的有 N 条工具行。
///
/// ## 夹具
///
/// `--lumi-ui-testing-message-list-standard` 植入 `Tool Group Target` 会话：
/// - 一条含 **3 个**工具调用的助手消息（正文为空 → 命中 `isToolExecutionOnly`）；
/// - 一条含 **1 个**工具调用的助手消息作为对照。
///
/// ## 定位方式
///
/// 按**标识符**定位，不按文案：摘要文案是本地化文本且带动态后缀
/// （耗时、失败数），按文案定位在非英文环境下必然失败。
final class LumiToolCallGroupCollapseUITests: LumiUITestCase {

    /// 折叠态的无障碍标识符（复述 `ToolCallGroupAccessibility`）。
    ///
    /// 必须按标识符定位：摘要文案随 `-AppleLanguages` 变化且带动态后缀。
    private enum Identifiers {
        /// 折叠态摘要行。
        static let summaryRow = "lumi.tool-call-group.summary"
        /// 展开按钮。
        static let expandButton = "lumi.tool-call-group.expand"
        /// 展开后的 popover 内容容器。
        static let popover = "lumi.tool-call-group.popover"
    }

    /// 首屏遮罩的稳定标识符（复述 `MessageLoadingView.identifier`）。
    private static let maskIdentifier = "lumi.message-list.loading-mask"

    /// 夹具植入的会话标题。
    private enum Conversations {
        /// V2（standard）：多工具调用折叠为一行摘要。
        static let toolGroup = "Tool Group Target"
    }

    /// 工具调用行的标识符（按 **工具调用 id**，见 `ToolCallRowAccessibility`）。
    ///
    /// 不按文案定位：行内文案是本地化文本且会被 `lineLimit(1)` 截断。
    private enum ToolCalls {
        static let groupRowIDs = ["group-1", "group-2", "group-3"]
        static let singleRowID = "single-1"
    }

    // MARK: - Lifecycle

    override func setUpWithError() throws {
        continueAfterFailure = false
        launchLumi(extraArguments: [
            // 确定性 LLM 供应商 + 隔离存储 + 植入工具调用组会话。
            //
            // - Important: `--lumi-ui-testing` 必须带上，它强制选中桩供应商
            //   `ui-test`（否则会拿到 UserDefaults 里残留的真实供应商）。
            //   夹具种入会话时会插入**用户消息**，`PluginAgentLoop.MessageObserver`
            //   因此会为每个会话自动跑一个回合；那 4 个回合的完成时刻各不相同，
            //   会把各会话的 `lastMessageAt` 推到「现在」并让会话列表顺序在
            //   run-to-run 之间摇摆。夹具已通过 `setAutoReplySuppressed` 阻断
            //   自动回合，但挂上桩供应商仍能保证「任何路径都不会打到真实供应商」。
            "--lumi-ui-testing",
            "--lumi-ui-testing-isolated-storage",
            "--lumi-ui-testing-message-list-standard",
        ])
        waitForMainWindow()
    }

    override func tearDownWithError() throws {
        terminateAppAndWait()
        try super.tearDownWithError()
    }

    // MARK: - Tests

    /// 多个工具调用折叠成一行摘要，展开后 popover 里逐条可见。
    func testMultipleToolCallsCollapseIntoSummaryAndExpandInPopover() throws {
        switchConversation(to: Conversations.toolGroup)
        waitForLoadingMaskToClear()

        // 断言 0：确实切到了目标会话**且**多调用已折叠成摘要行。
        //
        // 用**摘要行**作锚点，而不是会话行的 `isSelected` 或消息正文：
        // `isSelected` 在列表行被 SwiftUI 重建时可能长时间不翻转，
        // 消息正文则会被滚动出视口（列表默认钉在底部）。
        //
        // 摘要行同时也是「已折叠」的判据：折叠成立时，多条工具调用**不会**
        // 各自渲染成行（它们在 popover 里），因此主窗口里唯一的对应元素
        // 就是这行摘要。用工具调用行作锚点反而会误判——折叠时它本就不存在。
        let summary = element(identifier: Identifiers.summaryRow)
        XCTAssertTrue(
            summary.waitForExistence(timeout: 30),
            """
            未切换到目标会话，或多工具调用未折叠成摘要行\
            （identifier=\(Identifiers.summaryRow)）。\
            当前界面文本：\(diagnostics())
            """
        )

        // 断言 2：popover 尚未展开时，三条工具描述都不在界面上。
        //
        // 这一步证明「折叠」是真的发生了，而不是「摘要行 + 完整列表」同时存在。
        for rowID in ToolCalls.groupRowIDs {
            XCTAssertFalse(
                element(identifier: Self.rowIdentifier(rowID)).exists,
                "折叠态下工具调用行「\(rowID)」仍在界面上，说明没有折叠"
            )
        }

        // 断言 3：点击展开按钮后 popover 出现。
        let expand = element(identifier: Identifiers.expandButton)
        XCTAssertTrue(
            expand.waitForExistence(timeout: 10),
            "展开按钮未出现（identifier=\(Identifiers.expandButton)）"
        )
        // 等按钮**可点击**。消息列表是惰性行 + 首屏定位收敛，元素可能已经
        // 出现在 AX 树里，却因仍在滚动/重排而不可点击（此时 `click()` 会抛
        // 「Not hittable」——失败点指向点击动作，而不是被测行为）。
        XCTAssertTrue(
            waitForHittable(expand, timeout: 15),
            "展开按钮不可点击（identifier=\(Identifiers.expandButton)）"
        )
        expand.click()

        // popover 是独立窗口，必须**轮询**它的出现（见
        // waitForElementInAnyWindow 的说明：AX 查询只对当时快照求值）。
        XCTAssertTrue(
            waitForElementInAnyWindow(identifier: Identifiers.popover, timeout: 15),
            """
            点击后 popover 未出现（identifier=\(Identifiers.popover)）。\
            当前界面文本：\(diagnostics())
            """
        )

        // 断言 4：popover 里三条工具调用逐条可见。
        //
        // - Note: 必须**跨窗口**搜索。popover 在 macOS 上是独立窗口，
        //   `app.descendants` 的命中顺序在「主窗口消息区」与「popover 窗口」
        //   之间不确定（实测会偶发漏掉 popover 里的第 3 条），
        //   而限定在 `popover.descendants` 又会因 SwiftUI 的容器折叠而查不到。
        //   跨窗口搜索才是稳定做法：popover 里的内容**只可能**出现在 popover 窗口。
        for rowID in ToolCalls.groupRowIDs {
            XCTAssertTrue(
                waitForElementInAnyWindow(
                    identifier: Self.rowIdentifier(rowID),
                    timeout: 10
                ),
                "popover 内未出现工具调用行「\(rowID)」"
            )
        }
    }

    /// 单个工具调用**不折叠**：仍逐条铺开，不进 popover。
    func testSingleToolCallIsNotCollapsed() throws {
        switchConversation(to: Conversations.toolGroup)
        waitForLoadingMaskToClear()

        // 断言 1：确实切到了目标会话（用工具调用行的标识符作锚点，
        // 理由同上一条用例）。
        XCTAssertTrue(
            element(identifier: Self.rowIdentifier(ToolCalls.singleRowID))
                .waitForExistence(timeout: 30),
            """
            未切换到目标会话（工具调用行「\(ToolCalls.singleRowID)」未出现）。\
            当前界面文本：\(diagnostics())
            """
        )

        // 断言 2：单个调用的描述**直接铺开**在消息区，无需展开任何 popover。
        //
        // - Note: 这里刻意**不**断言「摘要行数量 == 1」。AX 树里摘要行的
        //   元素个数不稳定（SwiftUI 对同一标识符可能暴露 1~3 个匹配项），
        //   拿它做等值断言得到的是快照噪声而非行为判据。
        //   「单调用不折叠」真正要证明的是：它的内容**无需交互**就可见——
        //   若它被折叠进了 popover，这条描述在 popover 未展开时必然不可见。
        XCTAssertTrue(
            element(identifier: Self.rowIdentifier(ToolCalls.singleRowID))
                .waitForExistence(timeout: 30),
            """
            单个工具调用未直接铺开（行「\(ToolCalls.singleRowID)」不可见）。\
            单个调用不应被折叠。当前界面文本：\(diagnostics())
            """
        )

        // 断言 3：popover 未展开，故多调用的三条描述此刻都不在界面上。
        //
        // 顺带证明「多调用确实被折叠」——与断言 2 互为对照。
        for rowID in ToolCalls.groupRowIDs {
            XCTAssertFalse(
                element(identifier: Self.rowIdentifier(rowID)).exists,
                "折叠态下工具调用行「\(rowID)」仍在界面上，说明没有折叠"
            )
        }
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

    /// 等元素**可点击**。
    ///
    /// - Important: 元素「存在」不等于「可点击」。消息列表是惰性行 +
    ///   首屏定位收敛：元素可能已进 AX 树，却仍在滚动 / 重排中，
    ///   此时 `click()` 会抛「Not hittable」——失败点指向点击动作，
    ///   而不是被测行为。
    private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists && element.isHittable {
                return true
            }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return false
    }

    /// 等元素在**任何窗口**里按标识符出现。
    ///
    /// - Important: 必须**重试**。popover 在 macOS 上是独立窗口，
    ///   它的出现晚于点击；而 AX 查询是对**当时快照**求值的——
    ///   一次查询返回「不存在」不代表之后也不存在。
    ///   每次重试都重新遍历 `app.windows`，避免绑定到过期快照。
    private func waitForElementInAnyWindow(
        identifier: String,
        timeout: TimeInterval
    ) -> Bool {
        let query = NSPredicate(format: "identifier == %@", identifier)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for window in app.windows.allElementsBoundByIndex {
                if window.descendants(matching: .any).matching(query).firstMatch.exists {
                    return true
                }
            }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return false
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
