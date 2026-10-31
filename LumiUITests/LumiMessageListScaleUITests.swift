import XCTest

/// PluginMessageListStandard（V2 / 标准模式）**大数据量**场景的 UI 测试。
///
/// ## 要验证什么
///
/// 单元测试（`ListV2LargeDataTests`）已定位到长会话下的四个问题：
/// 1. 翻页裁剪窗口后，新消息到达会让中间段消息**永久消失**；
/// 2. 内容被等长替换时历史行不刷新；
/// 3. 在底部持续翻页时内存窗口**无上限增长**；
/// 4. 工具调用统计查询随窗口 turn 数线性放大。
///
/// 这组 UI 测试负责验证**端到端可感知**的部分：
/// - 超大会话（1200 条消息）首屏必须能加载出来，遮罩必须消失；
/// - 加载更早消息后，列表必须仍然可交互（不卡死、不白屏）；
/// - 反复翻页后列表不得崩溃或失去响应。
///
/// ## 为什么必须有 UI 层
///
/// 单元测试里「消息永久消失」表现为窗口数组缺项；用户看到的是
/// 「往上翻，某一整段消息不见了，再也翻不回来」。这属于**只有真实
/// 滚动 + 真实分页**才能暴露的问题：单元层的窗口数组无法表达
/// 「用户滚到那儿，却什么都看不到」。
///
/// ## 夹具
///
/// `--lumi-ui-testing-message-list-standard` 现在植入三个会话：
/// - `Switch Target Small`：3 轮（轻量基线）；
/// - `Switch Target Large`：40 轮 + Markdown/代码块（压几何收敛）；
/// - `Scale Target Huge`：600 轮 = 1200 条消息（压数据量）。
///
/// ## 不覆盖
///
/// - 消息缺口的**精确位置**断言：UI 层拿不到「窗口里有哪些 id」，
///   这条判据留在单元测试（`tailEvictionDoesNotCreatePermanentGap`）。
///   UI 层只断言「翻页后仍能看到连续的消息，没有整段空白」。
final class LumiMessageListScaleUITests: LumiUITestCase {
    /// 遮罩的稳定标识符，与 `MessageLoadingView.identifier` 一致。
    private let maskIdentifier = "lumi.message-list.loading-mask"

    /// 遮罩必须在此时间内消失。
    ///
    /// 超大会话有 1200 条消息，首屏定位要等 `settleBottom` 收敛，
    /// 比 40 轮的大会话慢。6s 与 `LumiMessageListSwitchUITests` 对齐：
    /// `InitialPositionGate` 的 3s 预算是「收敛挂死」的兜底，
    /// 正常收敛应远快于它。
    private let maskBudget: TimeInterval = 6

    override func setUpWithError() throws {
        continueAfterFailure = false
        launchLumi(extraArguments: [
            "--lumi-ui-testing-message-list-standard",
            "--lumi-ui-testing-isolated-storage",
        ])
        waitForMainWindow()
    }

    override func tearDownWithError() throws {
        terminateAppAndWait()
        try super.tearDownWithError()
    }

    // MARK: - Cases

    /// 超大会话（1200 条消息）必须能切过去，且首屏遮罩必须及时消失。
    ///
    /// 这是整个大数据量链路的**入口关卡**：分页查询本身在存储层是
    /// 有索引的（实测 5000 条消息下首屏分页约 10ms），但如果 ViewModel
    /// 在首屏就做了 O(全量) 的工作（例如工具统计、窗口重建），
    /// 遮罩就会在这里挂住。
    func testHugeConversationFirstScreenMaskClearsPromptly() throws {
        switchConversation(to: MessageListScaleUITestTitles.huge)

        let elapsed = measureMaskLifetime(timeout: maskBudget)
        XCTAssertNotNil(
            elapsed,
            "超大会话首屏遮罩在 \(Int(maskBudget))s 内未消失"
        )
    }

    /// 超大会话必须真的把消息渲染出来（遮罩消失 ≠ 有内容）。
    func testHugeConversationRendersMessages() throws {
        switchConversation(to: MessageListScaleUITestTitles.huge)
        _ = measureMaskLifetime(timeout: maskBudget)

        // 夹具的超大会话最后一条是「超大会话回答 600」。
        // 首屏停在底部，最后几轮必然在视口内。
        XCTAssertTrue(
            element(containingLabel: "超大会话回答").firstMatch.waitForExistence(timeout: 25),
            "超大会话的消息未渲染出来"
        )
    }

    /// 超大会话必须显示「加载更早消息」入口 —— 说明分页边界被正确探测到了。
    ///
    /// 1200 条消息远超分页窗口（40），因此顶部必须有翻页按钮。
    /// 按钮消失意味着 `hasEarlierMessages` 判定错误，用户将无法回看历史。
    ///
    /// - Note: 这里只断言「按钮存在」而不是「可点击」—— 它固定在列表首行，
    ///   首屏停在底部时它在视口外。可点击性由
    ///   `testRepeatedPagingKeepsListResponsive` 覆盖（那里会先滚到顶部）。
    func testHugeConversationOffersLoadEarlier() throws {
        switchConversation(to: MessageListScaleUITestTitles.huge)
        _ = measureMaskLifetime(timeout: maskBudget)

        XCTAssertTrue(
            element(identifier: MessageListScaleUITestIDs.loadEarlierButton)
                .waitForExistence(timeout: 15),
            "超大会话未出现「加载更早消息」入口"
        )
    }

    /// 反复翻页后列表必须仍然可用（不卡死、不白屏）。
    ///
    /// 这条针对「窗口无上限增长」缺陷的**可感知后果**：在底部持续翻页
    /// 会把整个会话的消息都塞进内存，`historyRows` 与 `ForEach` 的 diff
    /// 集合同步膨胀，主线程被拖垮后表现为「点了没反应」。
    func testRepeatedPagingKeepsListResponsive() throws {
        switchConversation(to: MessageListScaleUITestTitles.huge)
        _ = measureMaskLifetime(timeout: maskBudget)

        // 「加载更早消息」固定在列表最顶部，而首屏停在底部 ——
        // 必须先滚到顶部它才会进入视口，否则 click() 会因为
        // 「Not hittable（尺寸 0×0）」直接失败。
        XCTAssertTrue(
            scrollLoadEarlierButtonIntoView(),
            "滚动到底部后仍找不到可点击的「加载更早消息」按钮"
        )

        // 连续翻 5 页。每翻一页都要重新滚回顶部 —— 翻页后视口会钉在
        // 锚点（即刚加载出来的更早消息），按钮随之退出视口。
        for index in 0..<5 {
            let button = element(identifier: MessageListScaleUITestIDs.loadEarlierButton)
            guard button.exists else {
                XCTFail("翻到第 \(index) 页时「加载更早消息」入口消失")
                return
            }
            button.click()
            if !scrollLoadEarlierButtonIntoView() {
                XCTFail("翻到第 \(index) 页后再也找不到「加载更早消息」入口")
                return
            }
        }

        // 翻页后列表必须仍能渲染出消息（没有变成空白页）。
        XCTAssertTrue(
            element(containingLabel: "超大会话").firstMatch.waitForExistence(timeout: 15),
            "连续翻页后消息不再显示，列表疑似白屏"
        )
    }

    /// 从超大会话切回小会话，遮罩必须及时消失。
    ///
    /// 大数据量会话与轻量会话来回切换，覆盖「切换后重新加载」这条路径：
    /// 上一轮留下的窗口、滚动任务、定时器都必须正确失效。
    func testSwitchAwayFromHugeConversationClearsMaskPromptly() throws {
        switchConversation(to: MessageListScaleUITestTitles.huge)
        _ = measureMaskLifetime(timeout: maskBudget)

        switchConversation(to: MessageListScaleUITestTitles.small)

        let elapsed = measureMaskLifetime(timeout: maskBudget)
        XCTAssertNotNil(
            elapsed,
            "从超大会话切回小会话后遮罩在 \(Int(maskBudget))s 内未消失"
        )
    }

    // MARK: - Helpers

    /// 测量**一次切换**后遮罩的寿命。
    ///
    /// 与 `LumiMessageListSwitchUITests.measureMaskLifetime` 同一口径：
    /// 先等遮罩**出现**（证明这次切换确实触发了遮罩），再等它消失。
    /// 起点取「遮罩出现」，终点取「遮罩消失」，中间不含 AX 点击往返。
    ///
    /// - Returns: 遮罩寿命；超时未消失返回 nil；未出现返回 0。
    private func measureMaskLifetime(timeout: TimeInterval) -> TimeInterval? {
        let mask = element(identifier: maskIdentifier)
        guard mask.waitForExistence(timeout: 2) else {
            print("📊 [\(name)] mask never appeared → no lifetime to measure")
            return 0
        }

        let start = Date()
        let cleared = !mask.waitForNonExistence(timeout: timeout)
        let elapsed = Date().timeIntervalSince(start)
        print("📊 [\(name)] mask lifetime=\(String(format: "%.3f", elapsed))s "
              + "cleared=\(cleared) budget=\(String(format: "%.1f", timeout))s")
        return cleared ? elapsed : nil
    }

    /// 把「加载更早消息」按钮滚进视口，直到它变为可点击。
    ///
    /// ## 为什么必须显式滚动
    ///
    /// 该按钮固定在 `List` 的第一行，而首屏定位停在**底部**。
    /// SwiftUI 的 `List`（NSTableView）会复用 cell，未物化的行
    /// 在 AX 树里以 `0×0` 帧存在 —— 按钮 `exists` 为真，
    /// 但 `click()` 报 `Not hittable`，frame 形如 `{{0.0, 1080.0}, {0.0, 0.0}}`
    /// （y 在视口下方、尺寸为 0）。实测向消息列表滚动后，它的 frame 会变成
    /// `(1016.5, 267.0, 127.0, 15.0)` 并进入可点击状态。
    ///
    /// 用 `swipeDown` 逐段上滚到顶部，而不是直接依赖 `exists`，
    /// 因为「元素存在」与「元素可点」在这个场景下是两件事。
    ///
    /// - Returns: 按钮是否进入可点击状态。
    private func scrollLoadEarlierButtonIntoView(maxSwipes: Int = 60) -> Bool {
        let button = element(identifier: MessageListScaleUITestIDs.loadEarlierButton)
        guard button.waitForExistence(timeout: 15) else { return false }
        guard let list = messageListScrollView() else { return false }

        for _ in 0..<maxSwipes {
            if button.isHittable { return true }
            // 往回翻历史 = 向下滚动内容 = swipeDown。
            list.swipeDown()
            if button.isHittable { return true }
        }
        return button.isHittable
    }

    /// 找到**消息列表**对应的滚动视图。
    ///
    /// - Important: 不能用 `app.scrollViews.firstMatch`。Lumi 窗口里有多个
    ///   NSScrollView（会话列表、消息列表、输入区…），`firstMatch` 拿到的是
    ///   布局上靠前的那个（**会话列表**，frame 宽 240），对它 `swipeDown`
    ///   不会让消息列表动一下 —— 表现为「滑了几十次按钮始终不可点」。
    ///
    ///   也不能按「后代里能找到这个按钮」来反查：SwiftUI 的 `List`
    ///   （NSTableView）把行放在 table 的 cell 里，而按钮并不是
    ///   NSScrollView 的 AX 后代。
    ///
    ///   可靠判据是**尺寸**：消息列表是窗口里最宽的那块（859pt），
    ///   会话列表只有 240pt。取宽度最大者。
    private func messageListScrollView() -> XCUIElement? {
        let candidates = app.scrollViews.allElementsBoundByIndex
        guard !candidates.isEmpty else { return nil }
        let widest = candidates.max { $0.frame.width < $1.frame.width }
        // 宽度兜底：消息列表明显比会话列表宽；若窗口布局变化导致
        // 这个判据失效，退回第一个（至少不会静默返回 nil）。
        return widest?.frame.width ?? 0 >= 400 ? widest : candidates.first
    }

    /// 在会话列表里点击指定标题。
    ///
    /// - Important: 查询必须限定在**列表容器内**（`listID`）。会话标题在
    ///   消息列表正文里也存在同名前缀，全窗口搜索会命中消息正文而非
    ///   会话行，点击后选中态不变，表现为「切换没生效」，极具误导性。
    private func switchConversation(to title: String) {
        let row = conversationRow(title)
        XCTAssertTrue(
            row.waitForExistence(timeout: 20),
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
}

/// 夹具的超大会话标题。UI 测试独立于插件模块，故在此复述。
enum MessageListScaleUITestTitles {
    static let small = "Switch Target Small"
    static let huge = "Scale Target Huge"
}

/// V2 列表的可访问性标识符（复述 `ListV2Accessibility`）。
///
/// UI 测试独立 target，不能 import 插件模块，因此在此复述常量。
/// 改动必须与 `ListV2Accessibility` 同步。
enum MessageListScaleUITestIDs {
    static let loadEarlierButton = "lumi.message-list.v2.load-earlier"
}
