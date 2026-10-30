import XCTest

/// PluginMessageListStandard（V2 / 标准模式）「自动滚动没彻底滚到底」的 UI 测试。
///
/// ## 用户报告的症状
///
/// 用户已滚动到列表底部，新消息到达后**底部被输入框遮住一小截** ——
/// 列表没有真正停在内容底沿，最后一条消息的下缘落在输入框后面。
///
/// ## 为什么必须有 UI 层
///
/// 单元测试（`BottomStickyPinTests`）用真实 `NSScrollView` 复现了
/// 「文档在钉底之后继续变高 → 偏移量停在旧底沿」这一**机制**。
/// 但用户看到的是**像素**：新消息的底沿是否真的落在消息列表视口内。
///
/// 这两者之间隔着几层只有真实 App 才会出现的东西：
///
/// - SwiftUI `List` 的行**懒加载物化**（单元测试的裸 `NSScrollView` 没有 `List`）；
/// - Markdown 正文的**异步解析回填**（`MarkdownBlockRenderer` 缓存未命中时
///   先渲染空块、后台解析后再填充，行高随之增长）；
/// - 消息列表与输入框在真实窗口里的**相对布局**。
///
/// 「底部被输入框遮住」正是在这些因素叠加下才出现的，单元层无法表达。
///
/// ## 夹具与确定性
///
/// - `--lumi-ui-testing`：注册确定性 LLM 供应商，**不发起任何真实网络请求**。
///   模型 `ui-test-long` 产出 40 段正文（`段落 1。`…`段落 40。`），
///   足以把消息行撑得很高。
/// - `--lumi-ui-testing-isolated-storage`：数据目录重定向到临时目录。
///
/// ## 为什么不复用 `--lumi-ui-testing-message-list-standard` 夹具
///
/// 该夹具对**每个**会话调用 `setAutoReplySuppressed(true, for:)`，
/// 目的是让会话列表顺序在 run-to-run 之间稳定（见
/// `MessageListStandardAutoReplySuppressionTests`）。
///
/// 但被抑制的会话**发消息不会产生助手回复**（`MessageObserver` 是
/// 唯一会为 user 消息启动回合的观察者），本文件要断言的恰恰是
/// 「助手回复到达后列表跟到底部」，因此不能在该夹具的会话里发送。
///
/// 本文件改为在**全新会话**里发送：全新会话不在抑制集合内，
/// 自动回复正常触发；而「新会话从空列表开始」正好是用户报告场景的
/// 典型形态 —— 内容从零增长到很长。
///
/// ## 判据
///
/// 最后一条助手消息的 AX 帧必须**完整落在消息列表滚动视图的视口内**
/// （底沿不得越过视口底沿）。越过即代表列表没停在内容底沿，
/// 用户看到的就是「底部被输入框遮住」。
final class LumiMessageListBottomScrollUITests: LumiUITestCase {

    // MARK: - Constants

    /// 宿主外壳的可访问性标识符。
    private enum Shell {
        /// 聊天输入框。
        static let editor = "lumi.conversation-input.editor"
        /// 模型选择弹窗。
        static let modelPopover = "lumi.model-selector.popover"
    }

    /// 桩供应商的长文本模型名。
    ///
    /// 40 段正文 → 消息行足够高 → 「底部被遮住」有足够的表现空间。
    private enum StubModel {
        static let long = "ui-test-long"
    }

    /// 桩回复正文的固定前缀，用于定位最后一条助手消息。
    private static let replyPrefix = "段落"

    /// 允许的误差（pt）。
    ///
    /// AX 帧是整数像素，且列表底部有一条锚点 spacer，
    /// 因此允许少量误差。超过 1pt 就认为确实越界了。
    private static let tolerance: CGFloat = 1.0

    /// 回合结束后等待布局稳定的超时。
    private let settleTimeout: TimeInterval = 40

    // MARK: - Lifecycle

    override func setUpWithError() throws {
        continueAfterFailure = false
        launchLumi(extraArguments: [
            // 确定性 LLM 供应商（桩，不发真实请求）。
            "--lumi-ui-testing",
            // 隔离存储，避免污染本机数据。
            "--lumi-ui-testing-isolated-storage",
        ])
        waitForMainWindow()
    }

    override func tearDownWithError() throws {
        terminateAppAndWait()
        try super.tearDownWithError()
    }

    // MARK: - Cases

    /// 新消息到达后，列表必须滚到底 —— 最后一条助手消息必须完整可见。
    ///
    /// 这是本文件的核心用例。用户已停在底部，发送一条消息，
    /// 助手回复（40 段）到达后列表必须自动跟到底部。
    ///
    /// 修复前：文档高度在收敛循环退出**之后**继续增长（懒加载行物化 +
    /// Markdown 异步解析回填），且这类增长只发 `documentView` 的
    /// `frameDidChangeNotification`、不发 `clipView` 的
    /// `boundsDidChangeNotification` —— 只观察偏移量的 tracker 收不到信号，
    /// 于是列表停在旧底沿，最后一条消息的底沿落到视口之外，
    /// **被输入框遮住一小截**。
    func testNewMessageLandsFullyVisibleAtBottom() throws {
        // 先发一条消息把会话建出来（首条消息的回复来自默认模型，内容很短）。
        ensureConversationExists()

        // 再切到长文本桩模型：回复足够高，撑开消息行。
        selectStubModel(StubModel.long)

        // 发一条消息，触发一轮完整的「用户消息 + 助手回复」。
        XCTAssertTrue(
            typeAndSend("滚动到底测试", editorIdentifier: Shell.editor),
            "消息发送失败"
        )

        // 等助手回复完整落地（40 段正文）。
        XCTAssertTrue(
            waitForReplyContent(),
            "助手回复未渲染出来"
        )

        // 等布局稳定：列表几何不再变化。
        let list = try XCTUnwrap(messageListScrollView(), "找不到消息列表滚动视图")
        XCTAssertTrue(waitForGeometryToSettle(list), "列表几何迟迟不稳定")

        // 核心断言：最后一条助手消息必须完整落在消息列表视口内。
        assertLastReplyFullyVisible()
    }

    /// 连续发多条消息后，列表仍必须停在底部。
    ///
    /// 单条消息可能碰巧落在容差内；连续多条会让每次的行高增长叠加，
    /// 只要有一次没被补偿，底沿就会明显越界。
    func testRepeatedMessagesKeepBottomFullyVisible() throws {
        ensureConversationExists()
        selectStubModel(StubModel.long)

        for index in 1...3 {
            XCTAssertTrue(
                typeAndSend("连续滚动测试 \(index)", editorIdentifier: Shell.editor),
                "第 \(index) 条消息发送失败"
            )
            // 每一条都要等回复落地，否则几条消息会叠在同一帧里到达，
            // 断言就变成在测「同时到达」而不是「依次到达」。
            XCTAssertTrue(
                element(containingLabel: "段落 40").waitForExistence(timeout: settleTimeout),
                "第 \(index) 轮助手回复未渲染出来"
            )
        }

        let list = try XCTUnwrap(messageListScrollView(), "找不到消息列表滚动视图")
        XCTAssertTrue(waitForGeometryToSettle(list), "列表几何迟迟不稳定")

        assertLastReplyFullyVisible()
    }

    // MARK: - Assertions

    /// 断言最后一条助手消息完整落在消息列表视口内。
    ///
    /// - Important: 用「所有匹配元素里**底沿最低**的那个」来定位最后一条，
    ///   而不是「AX 树里最后一个匹配项」。SwiftUI `List` 会复用 cell，
    ///   未物化的行以 `0×0` 帧留在 AX 树里；取最后一个匹配项可能拿到一个
    ///   零尺寸的残留元素，断言会假失败。
    private func assertLastReplyFullyVisible(file: StaticString = #filePath, line: UInt = #line) {
        guard let list = messageListScrollView() else {
            XCTFail("找不到消息列表滚动视图", file: file, line: line)
            return
        }
        let viewport = list.frame

        let candidates = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", Self.replyPrefix))
            .allElementsBoundByIndex
            .filter { $0.frame.height > 0 && $0.frame.width > 0 }

        guard let last = candidates.max(by: { $0.frame.maxY < $1.frame.maxY }) else {
            XCTFail("找不到任何助手回复元素", file: file, line: line)
            return
        }

        let lastFrame = last.frame
        XCTAssertLessThanOrEqual(
            lastFrame.maxY,
            viewport.maxY + Self.tolerance,
            """
            最后一条助手消息的底沿超出了消息列表视口底沿 \
            (消息底沿 \(lastFrame.maxY) > 视口底沿 \(viewport.maxY))，\
            说明列表没有停在内容底沿 —— 用户看到的就是底部被输入框遮住。
            消息帧=\(lastFrame)，视口=\(viewport)
            """,
            file: file, line: line
        )
        XCTAssertGreaterThanOrEqual(
            lastFrame.minY,
            viewport.minY - Self.tolerance,
            "最后一条助手消息整体位于视口之上（消息 \(lastFrame)，视口 \(viewport)）",
            file: file, line: line
        )
    }

    // MARK: - Helpers

    /// 等助手回复的正文出现在消息列表里。
    ///
    /// ## 为什么不用 `element(containingLabel:)`
    ///
    /// Markdown 正文被拆成多个 block 渲染（`MarkdownBlockRenderer` 的
    /// `ForEach(blocks)`），AX 树里**每个 block 是一个独立元素**，
    /// 因此不存在「一个元素的 label 包含整段正文」这回事。
    ///
    /// 可靠判据是「消息列表的滚动视图里出现了含『段落』的元素」——
    /// 限定在滚动视图内是为了排除侧栏/输入框等处的同名文本。
    private func waitForReplyContent(timeout: TimeInterval = 40) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let hits = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@", Self.replyPrefix))
                .allElementsBoundByIndex
                .filter { $0.frame.height > 0 && $0.frame.width > 0 }
            if !hits.isEmpty { return true }
            usleep(300_000)
        }
        return false
    }

    /// 找到**消息列表**对应的滚动视图。
    ///
    /// - Important: 不能用 `app.scrollViews.firstMatch`。Lumi 窗口里有多个
    ///   NSScrollView（会话列表、消息列表、输入区…），`firstMatch` 拿到的是
    ///   布局上靠前的那个（**会话列表**，frame 宽 240）。
    ///   可靠判据是**尺寸**：消息列表是窗口里最宽的那块。
    ///   判据与 `LumiMessageListScaleUITests.messageListScrollView()` 一致。
    private func messageListScrollView() -> XCUIElement? {
        let candidates = app.scrollViews.allElementsBoundByIndex
        guard !candidates.isEmpty else { return nil }
        let widest = candidates.max { $0.frame.width < $1.frame.width }
        // 宽度兜底：消息列表明显比会话列表宽；若窗口布局变化导致
        // 这个判据失效，退回第一个（至少不会静默返回 nil）。
        return widest?.frame.width ?? 0 >= 400 ? widest : candidates.first
    }

    /// 等待列表几何稳定（连续若干次采样底沿不变）。
    ///
    /// 不用固定 sleep：布局何时收敛取决于懒加载物化与 Markdown 解析的时机，
    /// 固定等待要么太短（读到中间态）要么太慢（白等）。
    private func waitForGeometryToSettle(
        _ list: XCUIElement,
        timeout: TimeInterval = 15,
        stableSamples: Int = 4,
        interval: TimeInterval = 0.25
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var lastMaxY: CGFloat?
        var stableCount = 0
        while Date() < deadline {
            let maxY = list.frame.maxY
            if let lastMaxY, abs(maxY - lastMaxY) < 0.5 {
                stableCount += 1
                if stableCount >= stableSamples { return true }
            } else {
                stableCount = 0
            }
            lastMaxY = maxY
            usleep(UInt32(interval * 1_000_000))
        }
        return false
    }

    /// 确保当前已有一个会话被选中。
    ///
    /// ## 为什么必须先建会话
    ///
    /// 模型选择器的 `select(modelID:)`（`ModelSelectionCapabilityAdapter`）
    /// 在**有选中会话**时把模型钉到该会话上；没有会话时只改全局选中态。
    ///
    /// 而首条消息发送时才会 `createConversation` —— 也就是说，
    /// 「启动后先切模型、再发消息」这条顺序下，模型选择落在了**尚不存在**
    /// 的会话上，随后的新会话回落到全局默认模型（`ui-test-text`）。
    /// 表现为「明明选了长文本模型，回复却还是短文本」。
    ///
    /// 因此本文件统一先发一条消息把会话建出来，再切模型。
    ///
    /// - Note: 这条首条消息用的是默认模型（`ui-test-text`，正文
    ///   `UI Testing Reply`），内容很短，不会影响后续「行高增长」的观察。
    private func ensureConversationExists() {
        XCTAssertTrue(
            typeAndSend("建立会话", editorIdentifier: Shell.editor),
            "首条消息发送失败，会话未建立"
        )
        // 会话建立后，用户消息会出现在时间线上。
        XCTAssertTrue(
            element(anyLabelOf: ["建立会话"]).waitForExistence(timeout: 30),
            "首条用户消息未出现在时间线上，会话未建立"
        )
    }

    /// 切到指定桩模型。
    ///
    /// 复刻 `LumiAskUserUITests.selectStubModel`：UI 测试供应商
    /// `isLocal = true`，因此位于模型选择器的「本地」页签。
    private func selectStubModel(_ model: String) {
        let selectModelButton = app.buttons["Select Model"]
        XCTAssertTrue(
            selectModelButton.waitForExistence(timeout: 20),
            "缺少模型选择按钮"
        )
        selectModelButton.click()

        let popover = element(identifier: Shell.modelPopover)
        XCTAssertTrue(popover.waitForExistence(timeout: 10), "模型选择弹窗未出现")

        let localSegment = app.radioButtons["Local"]
        XCTAssertTrue(
            localSegment.waitForExistence(timeout: 5),
            "供应商列表缺少 Local 页签"
        )
        localSegment.click()
        // 页签切换后列表要重新筛选，留稳定期再断言，避免读到切换前的快照。
        sleep(1)

        let providerRow = element(identifier: "lumi.model-selector.provider.ui-test")
        XCTAssertTrue(
            providerRow.waitForExistence(timeout: 5),
            "本地供应商列表缺少 UI Test"
        )
        providerRow.click()

        let modelRow = element(identifier: "lumi.model-selector.model.\(model)")
        XCTAssertTrue(modelRow.waitForExistence(timeout: 5), "模型列表缺少 \(model)")
        modelRow.click()

        // 选中模型会关闭弹窗；等它消失，避免与后续点击争抢命中测试。
        let closed = popover.waitForNonExistence(timeout: 10)
        XCTAssertTrue(closed, "选中模型后弹窗未关闭，模型选择可能未生效")
        // 弹窗关闭后输入框需重新拿回焦点，否则紧随其后的点击会落空。
        sleep(1)
    }
}
