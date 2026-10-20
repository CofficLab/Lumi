import XCTest

/// goal 侧边栏的端到端 UI 测试。
///
/// ## 为什么需要这条
///
/// goal 插件的**逻辑层**有 113 个单元测试（状态机、工具契约、hook、fork），
/// 但**视图层此前零覆盖**：9 个 View 文件没有任何测试触达，UI 测试套件里
/// 也没有一条涉及 goal。侧边栏「没有活跃 goal 时整体不渲染、有活跃 goal 时
/// 逐行渲染任务」这条链路一旦坏掉，单元测试完全无感。
///
/// 渲染级测试（`GoalViewRenderTests`）能钉住几何，但它渲染的是**独立组件**，
/// 回答不了「工具创建出目标后，侧边栏真的出现在聊天区吗」——这必须驱动真实 App。
///
/// ## 确定性来源（三层夹具）
///
/// 1. `--lumi-ui-testing`：注册确定性 LLM 供应商。本文件切到 `ui-test-goal` 模型，
///    桩按**两段式**响应：首轮返回 `create_goal` 工具调用（目标被真正创建、
///    侧边栏出现），工具执行后第二轮返回固定收尾正文。
/// 2. `--lumi-ui-testing-isolated-storage`：数据根目录重定向到临时目录，
///    目标数据不污染用户真实数据库。
/// 3. 桩创建的 3 条任务不触发任务列表容器的高度封顶
///    （封顶阈值见 `SidebarView.maxTaskListHeight`），3 行任务全部可见可数。
///
/// 范式参照 `LumiAskUserUITests` 与 `LumiStopButtonCoverageUITests`。
final class LumiGoalUITests: LumiUITestCase {

    /// 与 `PluginGoalTask.GoalAccessibility` 保持一致。
    ///
    /// 必须按标识符定位：目标标题与任务名来自桩，**不随 `-AppleLanguages` 变化**；
    /// 而任务名同时也会出现在消息时间线的工具结果里，按文案定位会命中错误元素。
    ///
    /// 注意 SwiftUI 的 `Text` 在无障碍树里把正文放在 `value` 上、`label` 为空，
    /// 读文本要取 `value`（见 `text(of:)`）。
    ///
    /// UI 测试 target 无法 import 插件模块，故此处复述同一组常量，改动必须两边同步。
    private enum Identifiers {
        /// 侧边栏里的目标标题。
        static let goalTitle = "lumi.goal.title"
        /// 侧边栏标题栏右侧的进度文本（如「0/3」）。
        static let goalProgress = "lumi.goal.progress"
        /// 任务行标题。**每一行共用**，按数量统计要用 `matching(identifier:)`。
        static let taskTitle = "lumi.goal.task-title"
    }

    /// 模型选择器与聊天输入框的标识符。
    private enum Shell {
        static let modelPopover = "lumi.model-selector.popover"
        static let editor = "lumi.conversation-input.editor"
    }

    /// 桩供应商产出的稳定文案。
    ///
    /// 与 `PluginLLMProviderUITest.UITestFixtures` 对应。这些常量定义在 App 进程外，
    /// 故此处以字面量书写；改动桩文案会让本文件断言失败，属于预期的显式耦合。
    private enum Stub {
        static let goalTitle = "UI Testing Goal"
        static let taskTitles = [
            "UI Testing Task One",
            "UI Testing Task Two",
            "UI Testing Task Three",
        ]
    }

    /// 选中的桩模型名。
    ///
    /// 与 `UITestScenario.goal.rawValue` 一致。
    private static let stubModel = "ui-test-goal"

    // MARK: - Lifecycle

    override func setUpWithError() throws {
        continueAfterFailure = false
        launchLumi(extraArguments: [
            // 确定性 LLM 供应商 + 隔离存储。
            "--lumi-ui-testing",
            "--lumi-ui-testing-isolated-storage",
        ])
    }

    override func tearDownWithError() throws {
        // 等 App 真正退出，避免「上一个用例还在退出」漂移成「下一个用例偶发失败」。
        terminateAppAndWait()
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    /// 切到指定的桩模型。
    ///
    /// 与 `LumiAskUserUITests` 的同名私有方法同形：模型选择器是唯一能改变
    /// 「这轮对话由谁应答」的入口，不走它就没法拿到确定性行为。
    private func selectStubModel(_ model: String) {
        let selectModelButton = app.buttons["Select Model"]
        XCTAssertTrue(
            selectModelButton.waitForExistence(timeout: 20),
            "Action Bar 缺少模型选择按钮"
        )
        selectModelButton.click()

        let popover = element(identifier: Shell.modelPopover)
        XCTAssertTrue(
            popover.waitForExistence(timeout: 10),
            "模型选择弹窗未出现"
        )

        // UI 测试供应商 isLocal = true，因此它位于「本地」页签。
        let localSegment = app.radioButtons["Local"]
        XCTAssertTrue(
            localSegment.waitForExistence(timeout: 5),
            "供应商列表缺少 Local 页签"
        )
        localSegment.click()

        // 点击页签后列表要重新筛选，留一点稳定期再断言，避免读到切换前的快照。
        sleep(1)

        let providerRow = element(identifier: "lumi.model-selector.provider.ui-test")
        if !providerRow.waitForExistence(timeout: 5) {
            // 记录当前可见的供应商行，便于定位是「页签没切过去」还是「供应商没注册」。
            let rows = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", "lumi.model-selector.provider."))
                .allElementsBoundByIndex
                .map { "\($0.identifier)=\($0.label)" }
            XCTFail("本地供应商列表缺少 UI Test。实际可见：\(rows)")
        }
        providerRow.click()

        let modelRow = element(identifier: "lumi.model-selector.model.\(model)")
        XCTAssertTrue(
            modelRow.waitForExistence(timeout: 5),
            "模型列表缺少 \(model)"
        )
        modelRow.click()

        // 选中模型会关闭弹窗；等它消失，避免与后续点击争抢命中测试。
        _ = popover.waitForNonExistence(timeout: 10)
        // 弹窗关闭后输入框需要重新拿回键盘焦点，否则紧随其后的 typeText 会落空。
        sleep(1)
    }

    /// 匹配全部指定标识符的元素。
    ///
    /// 列表里的每一行共用同一标识符，按 `staticTexts[identifier]` 只会拿到第一行，
    /// 必须用 `matching(identifier:)` 取出全部匹配项。
    private func elements(identifier: String) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: identifier)
    }

    /// 取元素承载的文本。
    ///
    /// SwiftUI 的 `Text` 在 macOS 无障碍树里把文本放在 **`value`** 上，`label` 是空的。
    /// 实测：带 `accessibilityIdentifier` 的 `Text` 元素 `label` 为 `""`、
    /// `value` 才是正文。因此读文本一律走 `value`。
    private func text(of element: XCUIElement) -> String {
        element.value as? String ?? element.label
    }

    // MARK: - Tests

    /// 完整链路：发消息 → 模型发起 `create_goal` → 目标被创建 → 侧边栏出现并逐行渲染任务。
    ///
    /// 断言分层：
    /// 1. 侧边栏出现目标标题 → 工具真的被注册并执行了，不是「工具调用失败」；
    /// 2. 3 条任务全部渲染 → 任务行逐行渲染且没有漏行；
    /// 3. 进度文本为 `0/3` → 进度按任务总数算，且没把已完成数算进去。
    func testGoalSidebarRendersCreatedGoalAndItsTasks() throws {
        waitForMainWindow()
        selectStubModel(Self.stubModel)

        let prompt = "UI Testing Goal Probe"
        XCTAssertTrue(
            typeAndSend(prompt, editorIdentifier: Shell.editor),
            "未找到聊天输入框（identifier=\(Shell.editor)）"
        )
        XCTAssertTrue(
            element(anyLabelOf: [prompt]).waitForExistence(timeout: 30),
            "用户消息未出现在时间线上，回合可能未启动"
        )

        // 断言 1：目标标题出现。
        //
        // 侧边栏只在存在活跃 goal 时才渲染（`SidebarView` 的 `hasVisibleGoal`），
        // 因此标题出现即证明 `create_goal` 真的建出了目标。
        let goalTitle = element(identifier: Identifiers.goalTitle)
        XCTAssertTrue(
            goalTitle.waitForExistence(timeout: 60),
            """
            goal 侧边栏未出现（identifier=\(Identifiers.goalTitle)），\
            说明 create_goal 工具未被注册、未被调用，或目标未创建
            """
        )
        XCTAssertEqual(
            text(of: goalTitle),
            Stub.goalTitle,
            "侧边栏标题与桩创建的目标标题不一致"
        )

        // 断言 2：3 条任务全部渲染。
        let taskRows = elements(identifier: Identifiers.taskTitle)
        XCTAssertTrue(
            taskRows.firstMatch.waitForExistence(timeout: 30),
            "任务列表没有渲染出任何任务行（identifier=\(Identifiers.taskTitle)）"
        )
        XCTAssertEqual(
            taskRows.count,
            Stub.taskTitles.count,
            "任务行数与桩创建的任务数不一致"
        )
        // 每一行的文案都要对得上，确认渲染的是本次创建的目标而不是残留数据。
        let renderedTitles = taskRows.allElementsBoundByIndex.map { text(of: $0) }
        for expected in Stub.taskTitles {
            XCTAssertTrue(
                renderedTitles.contains(expected),
                "任务行缺少「\(expected)」。实际渲染：\(renderedTitles)"
            )
        }

        // 断言 3：进度文本按任务总数计算。
        let progress = element(identifier: Identifiers.goalProgress)
        XCTAssertTrue(
            progress.waitForExistence(timeout: 10),
            "侧边栏没有进度文本（identifier=\(Identifiers.goalProgress)）"
        )
        XCTAssertEqual(
            text(of: progress),
            "0/\(Stub.taskTitles.count)",
            "进度文本与预期不一致"
        )
    }
}
