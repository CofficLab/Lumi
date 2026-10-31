import XCTest
import AppKit

/// `ask_user` 挂起时，消息正文里不得出现「无法解析工具审批请求」。
///
/// ## 用户报告的现象
///
/// 「有时候会出现无法解析工具审批请求，但是似乎一切都是正常进行的。」
///
/// ## 现象解释
///
/// `ask_user`（向用户提问）的交互界面由**底部 ChatSection 固定项**展示
/// （`AskUserChatSection`），与消息正文里的工具行是两条独立通路。因此：
/// - 提问卡片照常出现在底部 → 用户能回答 → 回合照常恢复；
/// - 但消息正文里那条 `ask_user` 工具行被通用授权卡片渲染器接管了，
///   而授权卡片构造不出请求，于是渲染出一句「无法解析工具审批请求」。
///
/// 两者并存，就成了用户描述的「有错误提示，但一切正常」。
///
/// ## 根因
///
/// 提交 `9bc46bfea` 之后，AgentLoop 在持久化**任何**挂起结果时都把授权状态
/// 回落成 `pendingAuthorization`（不区分挂起原因）。`ask_user` 挂起时因此满足
/// `ToolApprovalRowRenderer.canRender` 的两条判据，被误接管；而它的载荷根本
/// 不是授权载荷（没有 `kind` 字段），构造不出授权请求 → 落到错误文案分支。
///
/// ## 为什么必须是 V2 详细模式
///
/// 自定义工具渲染器只在 V2/V3 启用（`allowsCustomToolRenderers` 在 V1/brief 下
/// 为 false）。V1 下消息正文走默认工具行，不会渲染这句错误文案——这正是
/// 用户说「**有时候**」出现的原因之一。
///
/// ## 断言分层
///
/// 1. 问题卡片出现 → 挂起链路本身是通的（排除「回合没起来」这种无关失败）；
/// 2. 消息正文里不得出现错误文案 → 这就是用户报告的那句话；
/// 3. 点选选项后卡片消失、桩收尾正文出现 → 证明「一切正常」，
///    避免把「整条链路都坏了」误判成同一个问题。
final class LumiAskUserApprovalMisclaimUITests: LumiUITestCase {

    /// `ask_user` 相关标识符。
    private enum Identifiers {
        /// 问题卡片容器。
        static let card = "lumi.ask-user.card"
        /// 选项按钮。
        static func option(_ index: Int) -> String { "lumi.ask-user.option.\(index)" }
    }

    /// 模型选择器与聊天输入框的标识符。
    private enum Shell {
        static let modelPopover = "lumi.model-selector.popover"
        static let editor = "lumi.conversation-input.editor"
    }

    /// 桩供应商产出的稳定文案。
    private enum Stub {
        static let question = "UI Testing Continue?"
        static let followUpResponse = "UI Testing Ask User Answered"
    }

    /// 「无法解析工具审批请求」这句错误提示。
    ///
    /// - Note: 该文案在 `Localizable.xcstrings` 里**没有英文翻译**，
    ///   因此即使 App 以 `-AppleLanguages (en)` 启动，界面显示的仍是中文原文。
    ///   这让断言不受 `-AppleLanguages` 影响，反而更稳定。
    private enum ErrorText {
        static let unparsableApprovalRequest = "无法解析工具审批请求"
    }

    // MARK: - Lifecycle

    override func setUpWithError() throws {
        continueAfterFailure = false
        launchLumi(extraArguments: [
            // 确定性 LLM 供应商 + 隔离存储。
            "--lumi-ui-testing",
            "--lumi-ui-testing-isolated-storage",
        ])
        waitForMainWindow()
    }

    override func tearDownWithError() throws {
        terminateAppAndWait()
        try super.tearDownWithError()
    }

    // MARK: - Tests

    /// `ask_user` 挂起时，消息正文不得渲染出「无法解析工具审批请求」。
    ///
    /// 这条用例直接复现用户报告的现象：提问卡片正常出现、流程一切正常，
    /// 但消息正文里多了一句看不懂的错误提示。
    func testAskUserSuspensionDoesNotRenderUnparsableApprovalMessage() throws {
        selectStubModel("ui-test-ask-user-yes-no")

        let prompt = "UI Testing Ask User Misclaim Probe"
        XCTAssertTrue(
            typeAndSend(prompt, editorIdentifier: Shell.editor),
            "未找到聊天输入框（identifier=\(Shell.editor)）"
        )

        // 断言 1：问题卡片出现——挂起链路本身是通的。
        //
        // 这一步是必要的：若回合根本没起来，问题卡片也不会出现，
        // 「错误文案不存在」就成了假通过。
        let card = element(identifier: Identifiers.card)
        XCTAssertTrue(
            card.waitForExistence(timeout: 60),
            """
            ask_user 的问题卡片未出现（identifier=\(Identifiers.card)），\
            回合可能未启动。当前界面文本：\(visibleTextSummary())
            """
        )
        XCTAssertTrue(
            element(anyLabelOf: [Stub.question]).waitForExistence(timeout: 10),
            "问题正文未渲染，桩产出的问题文案应为「\(Stub.question)」"
        )

        // 断言 2：消息正文里不得出现「无法解析工具审批请求」。
        //
        // 这就是用户报告的那句话。ask_user 的载荷不是授权载荷，
        // 通用授权卡片接管它之后构造不出请求，只能渲染出这句兜底文案。
        let errorText = element(anyLabelOf: [ErrorText.unparsableApprovalRequest])
        XCTAssertFalse(
            errorText.exists,
            """
            消息正文出现「\(ErrorText.unparsableApprovalRequest)」。\
            挂起的 ask_user 被通用工具授权卡片误接管了——它不是授权请求，\
            授权卡片构造不出请求，只能渲染出这句兜底文案。\
            当前界面文本：\(visibleTextSummary())
            """
        )
    }

    /// 镜像用例：流程确实一切正常（回答后回合恢复并收尾）。
    ///
    /// 这一条保证「一切正常」的部分被覆盖：修复误接管时不得破坏
    /// ask_user 的提问 → 回答 → 恢复链路。
    func testAskUserFlowStillWorksNormally() throws {
        selectStubModel("ui-test-ask-user-yes-no")

        let prompt = "UI Testing Ask User Normal Flow Probe"
        XCTAssertTrue(
            typeAndSend(prompt, editorIdentifier: Shell.editor),
            "未找到聊天输入框（identifier=\(Shell.editor)）"
        )

        let card = element(identifier: Identifiers.card)
        XCTAssertTrue(
            card.waitForExistence(timeout: 60),
            "ask_user 的问题卡片未出现"
        )

        // 点第一个选项。
        let option = element(identifier: Identifiers.option(0))
        XCTAssertTrue(
            option.waitForExistence(timeout: 10),
            "ask_user 的选项按钮未出现（identifier=\(Identifiers.option(0))）"
        )
        option.click()

        // 回合恢复并产出桩收尾正文——证明答案确实回传给了模型。
        XCTAssertTrue(
            element(anyLabelOf: [Stub.followUpResponse]).waitForExistence(timeout: 60),
            """
            回答后未渲染桩收尾回复「\(Stub.followUpResponse)」，\
            说明答案未回传给模型或回合未恢复
            """
        )
        XCTAssertTrue(
            waitForNonExistence(card, timeout: 20),
            "回答后问题卡片仍留在界面上"
        )
    }

    // MARK: - Helpers

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

        // 点击页签后列表要重新筛选，留一点稳定期再断言，避免读到切换前的快照。
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
        // 弹窗关闭后输入框需要重新拿回键盘焦点，否则紧随其后的粘贴会落空。
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
