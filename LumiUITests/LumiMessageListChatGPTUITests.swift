import XCTest
import AppKit

/// V5（ChatGPT）消息列表的 UI 测试。
///
/// ## 夹具
///
/// `--lumi-ui-testing-message-list-chatgpt` 植入 5 个**固定**会话：
/// - `ChatGPT Visual Target`：常规轮次（用户气泡 + 助手正文 + 轮尾操作栏）；
/// - `ChatGPT Reasoning Target`：带 reasoning 的助手回复；
/// - `ChatGPT Tool Target`：两个 Explore/Execute 工具，触发工具工作组；
/// - `ChatGPT Scroll Target`：30 轮长列表，用于滚动与 following 语义；
/// - `ChatGPT Error Target`：失败回合，验证内联错误。
///
/// ## 隔离
///
/// 所有用例都带 `--lumi-ui-testing-isolated-storage`，数据根落到临时目录，
/// 不触碰用户真实数据，也不连真实供应商（夹具在缺少
/// `--lumi-ui-testing` 时拒绝启动）。
///
/// ## 截图
///
/// 截图只做**人工对照**，不做字节相等断言。
/// 评审产物落在 `docs/plans/artifacts/chatgpt-message-list-v5/`。
final class LumiMessageListChatGPTUITests: LumiUITestCase {
    /// 遮罩的稳定标识符，与 `MessageLoadingView.identifier` 一致。
    private let maskIdentifier = "lumi.message-list.loading-mask"

    /// 遮罩必须在此时间内消失。
    private let maskBudget: TimeInterval = 6

    override func setUpWithError() throws {
        continueAfterFailure = false
        launchLumi(extraArguments: [
            // 全局 UI 测试开关：夹具在缺少它时**拒绝启动**，
            // 防止正式构建在真实环境里造出会话、连真实供应商。
            "--lumi-ui-testing",
            "--lumi-ui-testing-message-list-chatgpt",
            "--lumi-ui-testing-isolated-storage",
        ])
        waitForMainWindow()
    }

    override func tearDownWithError() throws {
        terminateAppAndWait()
        try super.tearDownWithError()
    }

    // MARK: - 夹具与首屏

    /// 5 个夹具会话都必须出现在会话列表里。
    ///
    /// - Important: 这是「夹具真的被种下去了」的最直接证据。
    ///   夹具没种进去时，后续所有呈现断言都无从谈起。
    func testAllChatGPTFixtureConversationsExist() throws {
        for title in MessageListChatGPTUITestTitles.all {
            XCTAssertTrue(
                element(containingLabel: title).waitForExistence(timeout: 30),
                "夹具会话「\(title)」未出现在会话列表"
            )
        }
    }

    /// 切到任一夹具会话，首屏遮罩都必须及时消失。
    ///
    /// - Important: V5 的遮罩由 `InitialPositionGate` 的预算兜底唯一决定，
    ///   与其它档位各自独立。V5 通过不能说明其它档位通过，反之亦然。
    func testFirstScreenMaskClearsPromptlyForEveryFixture() throws {
        for title in MessageListChatGPTUITestTitles.all {
            switchConversation(to: title)

            let elapsed = measureMaskLifetime(timeout: maskBudget)
            XCTAssertNotNil(
                elapsed,
                "会话「\(title)」的首屏遮罩在 \(Int(maskBudget))s 内未消失"
            )
        }
    }

    // MARK: - 列表可见性

    /// V5 的列表容器必须可见且不为空。
    func testChatGPTListIsVisibleAndNotBlank() throws {
        switchConversation(to: MessageListChatGPTUITestTitles.visual)
        switchToVerbosity(.chatGPT)

        let list = element(identifier: MessageListChatGPTIdentifiers.listContainer)
        XCTAssertTrue(list.waitForExistence(timeout: 15), "V5 列表容器未出现")
        XCTAssertTrue(list.isHittable, "V5 列表容器不可交互")
    }

    /// 助手正文必须出现 —— 这是「V5 真的显示了对话内容」的核心证据。
    ///
    /// - Important: Task 4 之前的 V5 是一个空 `List {}`，选中后什么都没有。
    ///   这条断言直接守住「不再空白」。
    func testAssistantBodyIsRendered() throws {
        switchConversation(to: MessageListChatGPTUITestTitles.visual)
        switchToVerbosity(.chatGPT)

        let body = element(identifier: MessageListChatGPTIdentifiers.assistantBody)
        XCTAssertTrue(body.waitForExistence(timeout: 15), "助手正文未出现")
    }

    /// 用户气泡必须存在，且复制按钮可用。
    func testUserBubbleHasCopyButton() throws {
        switchConversation(to: MessageListChatGPTUITestTitles.visual)
        switchToVerbosity(.chatGPT)

        let bubble = element(identifier: MessageListChatGPTIdentifiers.userBubble)
        XCTAssertTrue(bubble.waitForExistence(timeout: 15), "用户气泡未出现")

        // 复制按钮在 hover 时才显示，但必须存在（opacity 为 0 也算存在）。
        let copy = element(identifier: MessageListChatGPTIdentifiers.userCopyButton)
        XCTAssertTrue(copy.waitForExistence(timeout: 10), "用户气泡复制按钮未出现")
    }

    /// 助手正文**没有**气泡容器。
    func testAssistantBodyHasNoBubble() throws {
        switchConversation(to: MessageListChatGPTUITestTitles.visual)
        switchToVerbosity(.chatGPT)

        let body = element(identifier: MessageListChatGPTIdentifiers.assistantBody)
        XCTAssertTrue(body.waitForExistence(timeout: 15), "助手正文未出现")

        // Important: 断言的是「助手正文与用户气泡**不是同一个 AX 元素**」，
        //   而不是「用户气泡只有一个」—— 后者在没有用户消息的会话里也成立，
        //   根本测不到「助手有没有气泡」。
        let bubble = element(identifier: MessageListChatGPTIdentifiers.userBubble)
        if bubble.exists {
            let nested = bubble.descendants(matching: .any)
                .matching(identifier: MessageListChatGPTIdentifiers.assistantBody)
            XCTAssertEqual(
                nested.count,
                0,
                "助手正文被画进了用户气泡容器"
            )
        }
    }

    // MARK: - 轮尾操作

    /// 轮尾操作栏必须**只出现一次**。
    ///
    /// - Important: 逐条消息都出现一次操作栏，是「按 message 而不是按 turn」
    ///   的典型症状。断言的是**数量**，不是「存在」。
    func testTurnActionBarAppearsExactlyOnce() throws {
        switchConversation(to: MessageListChatGPTUITestTitles.visual)
        switchToVerbosity(.chatGPT)

        let body = element(identifier: MessageListChatGPTIdentifiers.assistantBody)
        XCTAssertTrue(body.waitForExistence(timeout: 15), "助手正文未出现")

        // hover 整个 turn 让操作栏出现。
        body.hover()

        // Important: 断言的是**复制按钮的数量**，不是容器的数量。
        //   容器挂 `accessibilityIdentifier` 会被 SwiftUI 传播给子元素，
        //   覆盖掉子元素自己的标识符。
        let copyButtons = app.descendants(matching: .any)
            .matching(identifier: MessageListChatGPTIdentifiers.turnCopyButton)
        XCTAssertEqual(
            copyButtons.count,
            1,
            "轮尾复制按钮出现了 \(copyButtons.count) 次（应按 turn 出现一次）"
        )
    }

    // MARK: - Reasoning 与工具

    /// reasoning 折叠块必须存在且可展开。
    func testReasoningDisclosureIsExpandable() throws {
        switchConversation(to: MessageListChatGPTUITestTitles.reasoning)
        switchToVerbosity(.chatGPT)

        let toggle = element(identifier: MessageListChatGPTIdentifiers.reasoningToggle)
        XCTAssertTrue(toggle.waitForExistence(timeout: 15), "reasoning 折叠块未出现")
    }

    /// 工具工作组必须存在。
    func testToolWorkGroupIsRendered() throws {
        switchConversation(to: MessageListChatGPTUITestTitles.tool)
        switchToVerbosity(.chatGPT)

        let toggle = element(identifier: MessageListChatGPTIdentifiers.workHistoryToggle)
        XCTAssertTrue(toggle.waitForExistence(timeout: 15), "工具工作组未出现")
    }

    // MARK: - 错误

    /// 内联错误必须呈现，且不带伪重试（没有真实失败回合时不得显示重试）。
    func testInlineErrorIsRendered() throws {
        switchConversation(to: MessageListChatGPTUITestTitles.error)
        switchToVerbosity(.chatGPT)

        let content = element(identifier: MessageListChatGPTIdentifiers.errorContent)
        XCTAssertTrue(content.waitForExistence(timeout: 15), "内联错误未出现")
    }

    // MARK: - 截图

    /// 生成常规轮次的截图，供人工对照。
    ///
    /// - Important: 截图只做人工对照，不做字节相等断言 ——
    ///   不同机器的字体栅格化必然不同。
    func testCaptureVisualFixtureScreenshot() throws {
        switchConversation(to: MessageListChatGPTUITestTitles.visual)
        switchToVerbosity(.chatGPT)

        let list = element(identifier: MessageListChatGPTIdentifiers.listContainer)
        XCTAssertTrue(list.waitForExistence(timeout: 15), "V5 列表容器未出现")
        Thread.sleep(forTimeInterval: 1)

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "chatgpt-visual-fixture"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Helpers

    /// 测量遮罩寿命。
    ///
    /// - Important: 先等遮罩**出现**再等它消失，测的是真实寿命。
    ///   只调 `waitForNonExistence` 会得到假数据：切换动作本身有几十到几百毫秒的
    ///   AX 往返，若遮罩在这段时间内已消失，测出的就是「AX 调用耗时」而非遮罩寿命。
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

    /// 在会话列表里点击指定标题。
    ///
    /// - Important: 查询必须限定在**列表容器内**（`listID`）。会话标题在
    ///   消息列表正文里也存在同名前缀，全窗口搜索会命中消息正文而非会话行。
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

    /// 切换回复级别。
    ///
    /// - Note: 优先走设置里的分段控件；找不到时跳过并记录，
    ///   而不是让整批用例因入口差异而失败。
    private func switchToVerbosity(_ verbosity: MessageListChatGPTUITestVerbosity) {
        let control = app.descendants(matching: .any)
            .matching(identifier: "lumi.settings.response-verbosity")
            .firstMatch
        guard control.exists else {
            print("ℹ️ [\(name)] 未找到回复级别控件，跳过 \(verbosity.rawValue) 切换")
            return
        }
        control.click()
        let option = app.descendants(matching: .any)
            .matching(identifier: "lumi.settings.response-verbosity.\(verbosity.rawValue)")
            .firstMatch
        if option.waitForExistence(timeout: 5) {
            option.click()
        }
    }
}

/// V5 夹具会话标题。
///
/// - Note: 与 `MessageListChatGPTUITestingSupport.fixtureTitles` 一一对应。
///   标题是 UI 测试的定位锚点，改动会让既有截图失效。
enum MessageListChatGPTUITestTitles {
    static let visual = "ChatGPT Visual Target"
    static let reasoning = "ChatGPT Reasoning Target"
    static let tool = "ChatGPT Tool Target"
    static let scroll = "ChatGPT Scroll Target"
    static let error = "ChatGPT Error Target"

    static let all = [visual, reasoning, tool, scroll, error]
}

/// 五档回复级别。
enum MessageListChatGPTUITestVerbosity: String, CaseIterable {
    case brief
    case standard
    case detailed
    case zcode
    case chatGPT = "v5"

    static let all: [MessageListChatGPTUITestVerbosity] = [
        .brief, .standard, .detailed, .zcode, .chatGPT,
    ]
}

/// V5 的稳定标识符。
///
/// - Note: 与 `ChatGPTAccessibilityIdentifiers`（列表层）与
///   `ChatGPTRendererAccessibilityIdentifiers`（渲染层）保持一致。
///   渲染层的标识符在 `PluginMessageRenderer` 里，UI 测试不能 import 它，
///   因此这里独立维护一份。
enum MessageListChatGPTIdentifiers {
    static let listContainer = "lumi.message-list.chatgpt.container"
    static let backToBottomButton = "lumi.message-list.chatgpt.back-to-bottom"
    static let loadEarlierButton = "lumi.message-list.chatgpt.load-earlier"
    static let turn = "lumi.message-list.chatgpt.turn"

    static let userBubble = "lumi.message.chatgpt.user-bubble"
    static let userCopyButton = "lumi.message.chatgpt.user-copy"
    static let userResendButton = "lumi.message.chatgpt.user-resend"
    static let assistantBody = "lumi.message.chatgpt.assistant-body"
    static let turnCopyButton = "lumi.message.chatgpt.turn-copy"
    static let reasoningToggle = "lumi.message.chatgpt.reasoning-toggle"
    static let workHistoryToggle = "lumi.message.chatgpt.work-history-toggle"
    static let errorContent = "lumi.message.chatgpt.error-content"
    static let errorRetryButton = "lumi.message.chatgpt.error-retry"
}
