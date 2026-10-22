import XCTest
import AppKit

/// 复现用户报告的缺陷：对话卡在「等待你的输入…」，但界面上没有任何卡片可回答。
///
/// ## 用户报告的现象
///
/// 高风险工具（`edit_file`）触发授权等待后，用户按下停止。回合确实结束了
/// （发送按钮回来了），但聊天区底部仍显示「等待你的输入…」，而且**没有任何
/// 授权卡片**可以点——提示说有东西在等你，但等待的东西已经不存在了。
///
/// ## 为什么必须驱动真实 App
///
/// 单元测试（`AuthorizationActivityResidueTests`）能锁住「授权解决后
/// activity 不得停在 `waitingForUser`」这一层状态机语义，但它回答不了用户
/// 真正遇到的问题：**在真实 App 里，授权处理完后那条提示会不会消失**。
///
/// 提示的渲染路径经过 SwiftUI 状态分发、`List` 惰性行、以及
/// `ConversationStateVM` 的投影——这些都必须在真实进程里才能验。
///
/// ## 夹具
///
/// 1. `--lumi-ui-testing`：注册确定性 LLM 供应商。切到 `ui-test-approval`
///    模型后，桩会发出一个 `edit_file` 工具调用。
///    `EditFileTool.permissionRiskLevel` 恒为 `.high`（`requiresPermission == true`），
///    因此界面必然弹出授权卡片并把回合挂起。
/// 2. `--lumi-ui-testing-isolated-storage`：数据根目录重定向到临时目录。
/// 3. `--lumi-ui-testing-message-list-standard`：使用 V2 消息列表。
///    V2/V3 的活动提示文案是「等待你的输入…」（`MessageListServices`），
///    与用户截图一致；V1 走的是「等待你的确认」，是另一条渲染路径。
///
/// ## 范式
///
/// 参照 `LumiToolApprovalSwitchUITests`（授权卡片）与 `LumiAskUserUITests`
/// （挂起/恢复链路）。
final class LumiAuthorizationStopActivityUITests: LumiUITestCase {

    /// 授权卡片与状态提示的标识符/文案。
    private enum Identifiers {
        /// 授权卡片容器。
        static let card = "lumi.tool-approval.card"
        /// 「拒绝」按钮。
        static let reject = "lumi.tool-approval.reject"
    }

    private enum Shell {
        static let modelPopover = "lumi.model-selector.popover"
        static let editor = "lumi.conversation-input.editor"
    }

    /// 桩产出的稳定文案。
    private enum Stub {
        /// 工具行展示的操作描述里必然出现的文件名。
        ///
        /// `EditFileTool.displayDescription` 产出「编辑 <文件名>」，
        /// 文件名由桩的 `file_path` 参数决定，因此这段文本是稳定的。
        /// 它用于证明「工具行确实被渲染了」——否则「状态提示不存在」
        /// 可能只是因为整轮都没画出来，测试就成了假通过。
        static let toolAnchor = "lumi-ui-test-approval.txt"

        /// 用户做出授权决定后，桩在第二轮给出的收尾正文。
        ///
        /// 桩只有在请求体里看到 `role=tool` 消息（即授权决定确实回传给了
        /// 模型）时才会产出这段正文，因此它是「决定已被受理」的确定性证据。
        static let followUpResponse = "UI Testing Approval Resolved"
    }

    /// V2/V3 活动提示在 `waitingForUser` 时的文案。
    ///
    /// 来自 `MessageListServices.activityMessage(for:)`：
    /// `case .waitingForUser: content = String(localized: "status.waiting-for-user", ...)`。
    ///
    /// - Note: 这是本地化文案，断言依赖 `-AppleLanguages (en)`（基类已设）。
    ///   若要改成按标识符定位，需要给状态提示补一个无障碍标识符——
    ///   那是修复阶段的事，此处先用文案定位把缺陷复现出来。
    private enum Activity {
        static let waitingForUser = "等待你的输入…"
    }

    // MARK: - Lifecycle

    override func setUpWithError() throws {
        continueAfterFailure = false
        launchLumi(extraArguments: [
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

    /// 授权等待中按下停止 → 「等待你的输入…」必须消失。
    ///
    /// 断言分层：
    /// 1. 授权卡片出现 → 授权链路本身是通的，回合确实挂起了；
    /// 2. 「等待你的输入…」出现 → 活动提示确实反映了挂起状态；
    /// 3. 按下停止 → 回合终止；
    /// 4. **「等待你的输入…」消失** → 这正是用户报告的缺陷判据；
    /// 5. 授权卡片也不存在 → 证明提示指向的「等待对象」确实已经没了，
    ///    因此「提示还在」就是纯粹的残留状态。
    func testWaitingActivityDisappearsAfterStoppingSuspendedTurn() throws {
        selectStubModel("ui-test-approval")

        let prompt = "UI Testing Approval Stop Probe"
        XCTAssertTrue(
            typeAndSend(prompt, editorIdentifier: Shell.editor),
            "未找到聊天输入框（identifier=\(Shell.editor)）"
        )
        XCTAssertTrue(
            element(anyLabelOf: [prompt]).waitForExistence(timeout: 30),
            "用户消息未出现在时间线上，回合可能未启动"
        )

        // 断言 1：授权卡片出现（回合挂起等待授权）。
        let card = element(identifier: Identifiers.card)
        XCTAssertTrue(
            card.waitForExistence(timeout: 60),
            """
            高风险工具的授权卡片未出现（identifier=\(Identifiers.card)），\
            说明模型未发起工具调用，或工具未被判定为需要授权。\
            当前界面文本：\(visibleTextSummary())
            """
        )

        // 断言 2：活动提示显示「等待你的输入…」。
        let waitingHint = element(anyLabelOf: [Activity.waitingForUser])
        XCTAssertTrue(
            waitingHint.waitForExistence(timeout: 30),
            """
            授权等待中未出现活动提示「\(Activity.waitingForUser)」。\
            当前界面文本：\(visibleTextSummary())
            """
        )

        // 断言 3：按下停止，让挂起的回合终止。
        stopCurrentTurn()

        // 断言 4：活动提示必须消失。
        //
        // 这是用户报告的缺陷判据。回合已终止，但活动状态仍停在
        // `waitingForUser`，于是提示永远留在界面上。
        XCTAssertTrue(
            waitForNonExistence(waitingHint, timeout: 30),
            """
            回合已停止，但活动提示「\(Activity.waitingForUser)」仍留在界面上。\
            提示说有东西在等待用户，但此时授权卡片已不存在，用户无从作答。\
            当前界面文本：\(visibleTextSummary())
            """
        )

        // 断言 5：授权卡片确实已消失。
        //
        // 这一条让断言 4 有意义：卡片没了 + 提示还在 = 纯粹的残留状态，
        // 而不是「确实还有东西在等，只是卡片没画出来」。
        XCTAssertTrue(
            waitForNonExistence(card, timeout: 20),
            "授权卡片在回合停止后仍留在界面上"
        )
    }

    /// 授权被「拒绝」后，「等待你的输入…」必须消失。
    ///
    /// 这是本文件最贴近用户报告的一条：拒绝是**用户主动处理完授权**的路径，
    /// 回合会继续往下走（工具不执行，但模型会收到拒绝结果并继续推理），
    /// 因此回合并不处于「等用户」的语义状态——活动提示却还停在
    /// `waitingForUser`，于是提示与实际状态脱节。
    ///
    /// 单元测试 `AuthorizationActivityResidueTests` 已锁住这一层状态机语义；
    /// 本条负责验证它在真实 App 里的可观测表现。
    func testWaitingActivityDisappearsAfterRejectingAuthorization() throws {
        selectStubModel("ui-test-approval")

        let prompt = "UI Testing Approval Reject Probe"
        XCTAssertTrue(
            typeAndSend(prompt, editorIdentifier: Shell.editor),
            "未找到聊天输入框（identifier=\(Shell.editor)）"
        )

        // 授权卡片出现 → 回合挂起等待授权。
        let card = element(identifier: Identifiers.card)
        XCTAssertTrue(
            card.waitForExistence(timeout: 60),
            """
            高风险工具的授权卡片未出现（identifier=\(Identifiers.card)）。\
            当前界面文本：\(visibleTextSummary())
            """
        )

        // 活动提示显示「等待你的输入…」。
        let waitingHint = element(anyLabelOf: [Activity.waitingForUser])
        XCTAssertTrue(
            waitingHint.waitForExistence(timeout: 30),
            """
            授权等待中未出现活动提示「\(Activity.waitingForUser)」。\
            当前界面文本：\(visibleTextSummary())
            """
        )

        // 点「拒绝」：授权决定被受理，回合继续。
        let reject = element(identifier: Identifiers.reject)
        XCTAssertTrue(
            reject.waitForExistence(timeout: 10),
            "「拒绝」按钮未出现（identifier=\(Identifiers.reject)）"
        )
        reject.click()

        // 桩的收尾正文是「拒绝已回传给模型」的确定性证据——它只有在请求体里
        // 看到 `role=tool` 消息（即授权决定确实回了传）时才会产出。
        XCTAssertTrue(
            element(anyLabelOf: [Stub.followUpResponse]).waitForExistence(timeout: 60),
            """
            拒绝后未渲染桩收尾回复「\(Stub.followUpResponse)」，\
            说明授权决定未回传给模型或回合未恢复。\
            当前界面文本：\(visibleTextSummary())
            """
        )

        // 关键断言：活动提示必须消失。
        XCTAssertTrue(
            waitForNonExistence(waitingHint, timeout: 30),
            """
            授权已被拒绝、回合已继续，但活动提示「\(Activity.waitingForUser)」仍留在界面上。\
            提示说有东西在等待用户，但授权早已处理完毕。\
            当前界面文本：\(visibleTextSummary())
            """
        )
    }

    // MARK: - Helpers

    /// 按下停止按钮，终止当前回合。
    ///
    /// 停止按钮与发送按钮互斥（由 `canStop` 决定），因此挂起回合期间
    /// 停止按钮必然可用——这正是 `ConversationStateSnapshot.canStop`
    /// 把 `.suspended` 也算作「还有没干完的活」的原因。
    private func stopCurrentTurn() {
        let stop = element(identifier: "lumi.conversation-input.stop")
        XCTAssertTrue(
            stop.waitForExistence(timeout: 20),
            """
            未找到停止按钮（identifier=lumi.conversation-input.stop）。\
            挂起回合应当可停止；若按钮不存在，说明「挂起 → 可停」的判定也坏了。\
            当前界面文本：\(visibleTextSummary())
            """
        )
        stop.click()
    }

    /// 切到 UI 测试供应商的指定模型。
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
        sleep(1)

        let providerRow = element(identifier: "lumi.model-selector.provider.ui-test")
        if !providerRow.waitForExistence(timeout: 5) {
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

        _ = popover.waitForNonExistence(timeout: 10)
        sleep(1)
    }

    /// 采集当前界面上可见的文本片段，用于失败诊断。
    private func visibleTextSummary() -> String {
        let texts = app.descendants(matching: .staticText)
            .allElementsBoundByIndex
            .compactMap(\.label)
            .filter { !$0.isEmpty }
        return texts.prefix(12).joined(separator: " | ")
    }
}
