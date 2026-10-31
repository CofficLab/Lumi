import XCTest

/// error 消息 header 上「重试」按钮的 UI 测试。
///
/// 回归背景：回合失败后 `AgentLoopManager.currentTurnID(for:)` 曾返回 `nil`
/// （`TurnRuntime.turnID` 直接透传 `TurnPhase.turnID`，而终态 phase 不带 turnID），
/// 导致 `canRetryTurn` 恒为 false —— 按钮虽然渲染出来，但点击后被 `guard`
/// 静默挡掉：用户点了完全没有反应，也不产生任何错误日志。
///
/// 单元测试能锁住判定逻辑，但只有驱动真实 App 才能证明「按钮出现」且「点击真的重试」。
///
/// ## 确定性来源（两层夹具）
///
/// 1. `--lumi-ui-testing-error-retry`：向 Chat 会话植入一个真实的 `.failed`
///    回合 + 一条 error 消息（见 `ErrorRetryUITestingSupport`）。
/// 2. `--lumi-ui-testing`：注册 UI 测试专用 LLM 供应商并强制选中
///    `ui-test-text`（见 `PluginUITestProvider`）。这条非常关键——
///
///    - 此前重试会走真实 AgentLoop 生产路径，回合结局取决于机器上是否配置了
///      可用的 LLM：可能成功、可能再次失败、可能产生多条消息，界面层面的结果
///      并不唯一。测试因此只能断言「新回合启动了」，无法断言重试后的终态。
///    - 现在选中的是确定性桩：重试必定产出固定正文 `UI Testing Reply`。
///      断言可以直接写死期望的界面内容。
///
/// 3. `--lumi-ui-testing-isolated-storage`：把数据根目录重定向到临时目录，
///    避免测试会话污染用户真实数据库。
///
/// 范式参照 MiniMax 的 `--lumi-ui-testing` 桩网络注入；两者可同时生效。
final class LumiErrorRetryTurnUITests: XCTestCase {
    private var app: XCUIApplication!

    private enum Identifiers {
        /// 与 `RetryTurnButton.accessibilityIdentifier` 保持一致。
        /// 按钮的 AX label 是本地化文案（en 为 "Retry"），跨语言不稳定，必须按标识定位。
        static let retryTurnButton = "lumi.message.error.retry-turn"
        /// 与 `ErrorMessageView.contentAccessibilityIdentifier` 保持一致。
        static let errorContent = "lumi.message.error.content"
        /// 与 `ErrorRetryUITestingSupport.retryMarkerContent` 保持一致。
        /// 点击重试后新回合启动时由夹具插入，作为「新回合真的启动了」的确定性证据。
        static let retryMarker = "UI Testing Retry Accepted"
    }

    /// 重试成功后桩产出的固定回复正文。
    ///
    /// 与 `PluginLLMProviderUITest` 的 `UITestFixtures.textResponse` 对应。
    /// 该常量是 UI 测试进程外定义的，所以此处以字面量书写；
    /// 改动桩文案时这个断言会失败，属于预期的显式耦合。
    private enum StubReply {
        static let text = "UI Testing Reply"
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
            // 植入确定性失败回合，见 ErrorRetryUITestingSupport。
            "--lumi-ui-testing-error-retry",
            // 注册并强制选中确定性桩供应商，让重试后的回合结局可断言。
            "--lumi-ui-testing",
            // 隔离数据根目录，避免测试会话污染用户真实数据库。
            "--lumi-ui-testing-isolated-storage",
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        // 等 App 真正退出：terminate() 是异步的，不等会让「上一个用例还在退出」
        // 漂移成「下一个用例偶发失败」。本类继承 XCTestCase，故内联实现。
        if app.state != .notRunning {
            app.terminate()
            let stopped = NSPredicate(
                format: "state == %d",
                XCUIApplication.State.notRunning.rawValue
            )
            _ = XCTWaiter().wait(
                for: [XCTNSPredicateExpectation(predicate: stopped, object: app)],
                timeout: 10
            )
        }
        try super.tearDownWithError()
    }

    private func element(identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func element(anyLabelOf labels: [String]) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label IN %@ OR value IN %@", labels, labels))
            .firstMatch
    }

    /// 核心用例：失败回合的错误消息 header 上必须出现「重试」按钮，
    /// 且点击后必须真实重新发起回合并产出确定性回复。
    ///
    /// 三个断言层层递进：
    /// 1. 按钮出现；
    /// 2. 夹具标记消息出现 —— 新回合确实启动了（由 `.started` 事件驱动，与回合结局无关）；
    /// 3. 桩回复出现 —— 新回合不仅启动，而且**成功跑完**并把结果渲染到了界面上。
    ///
    /// 第 3 条是引入 `--lumi-ui-testing`（确定性供应商）后才写得出来的断言。
    /// 在此之前，重试会走真实 LLM，结局可能是成功 / 再次失败 / 产生多条消息，
    /// 界面层面的结果并不唯一，测试只能停在第 2 条。现在回复正文固定，
    /// 因此可以断言「界面确实变成了预期的样子」，而不只是「动作被受理了」。
    ///
    /// 缺陷版本中 `currentTurnID` 为 nil → 按钮点了没反应 → 标记消息不出现，
    /// 本用例超时失败。
    func testRetryTurnButtonAppearsOnFailedTurnAndRetries() throws {
        XCTAssertTrue(
            element(identifier: "root.main").waitForExistence(timeout: 30),
            "主窗口未就绪"
        )

        // 夹具 error 行已渲染。
        XCTAssertTrue(
            element(identifier: Identifiers.errorContent).waitForExistence(timeout: 20),
            "UI 测试夹具的 error 消息未出现（identifier=\(Identifiers.errorContent)）"
        )

        // 夹具会话已由夹具设成 .detailed，header 操作按钮常驻显示，无需 UI 交互切换。

        // 关键断言 1：按钮确实出现。
        //
        // - Note: 不断言 `isHittable`。该按钮位于消息 header 的按钮组内，
        //   `hittable` 取决于当前是否命中该行，SwiftUI 命中测试的时序在 UI 测试里
        //   不稳定；`waitForExistence` 之后直接 `click()` 即可，点击失败会明确报错。
        let retryButton = element(identifier: Identifiers.retryTurnButton)
        XCTAssertTrue(
            retryButton.waitForExistence(timeout: 15),
            "error 消息 header 上缺少重试按钮（identifier=\(Identifiers.retryTurnButton)）"
        )

        // 关键断言 2：点击必须真实重跑一个回合 —— 夹具标记消息必须出现。
        let marker = element(anyLabelOf: [Identifiers.retryMarker])
        XCTAssertFalse(
            marker.exists,
            "点击前不应存在重试标记消息"
        )

        retryButton.click()

        XCTAssertTrue(
            marker.waitForExistence(timeout: 40),
            """
            点击重试后夹具标记消息「\(Identifiers.retryMarker)」未出现，\
            说明 retryTurn 未被真实受理（回合仍停留在原失败状态）
            """
        )

        // 关键断言 3：新回合必须跑完并把桩回复渲染出来。
        //
        // 这是引入确定性供应商后新增的断言。此前无法写出这一条：重试走真实
        // LLM，可能再次失败，界面终态不可预期。现在选中的是 `ui-test-text`，
        // 回合必然成功且回复正文固定，因此「重试后界面出现这段文字」是可断言的。
        let reply = element(anyLabelOf: [StubReply.text])
        XCTAssertTrue(
            reply.waitForExistence(timeout: 40),
            """
            重试后的回合未渲染出桩回复「\(StubReply.text)」，\
            说明回合未跑完或回复未落到消息列表
            """
        )

        // App 未崩溃：主窗口仍在。
        XCTAssertTrue(
            element(identifier: "root.main").exists,
            "点击重试后主窗口消失，App 可能已崩溃"
        )
    }
}