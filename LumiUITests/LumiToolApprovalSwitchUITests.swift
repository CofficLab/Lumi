import XCTest
import AppKit

/// 高风险工具授权的端到端 UI 测试。
///
/// ## 要验证的问题
///
/// 用户报告：**工具调用的授权界面，在用户已经处理过之后又出现了**——
/// 尤其是「切到其他对话再切回」之后，授权卡片又冒出来，让人以为刚才的决定没生效。
///
/// 单元测试能锁住链路上的每一段（授权终态落库、列表行携带终态、渲染层不再命中
/// 授权卡片），但回答不了用户真正遇到的那个问题：**在真实 App 里切走再切回，
/// 授权界面到底还看不看得见**。
///
/// 授权卡片由 SwiftUI 渲染、由 `List` 惰性行承载，还经过一层「工具结果解析缓存」
/// ——这些都必须在真实进程里才能验。
///
/// ## 夹具
///
/// 1. `--lumi-ui-testing`：注册确定性 LLM 供应商。本文件切到
///    `ui-test-approval` 模型，桩会发出一个 `edit_file` 工具调用。
///    `EditFileTool.permissionRiskLevel` 恒为 `.high`（需要用户授权），
///    因此界面必然弹出授权卡片。
/// 2. `--lumi-ui-testing-isolated-storage`：数据根目录重定向到临时目录。
/// 3. `--lumi-ui-testing-message-list-standard`：植入两个可切换的会话
///    （`Switch Target Small` / `Switch Target Large`）——没有第二个会话
///    就无法触发「切走再切回」这条路径。
///
/// ## 为什么点「拒绝」而不是「允许」
///
/// 「允许」会真的执行 `edit_file`（改文件），UI 测试不该对用户的工作区
/// 产生副作用。「拒绝」走的是同一条授权终态落库路径
/// （`authorizationState = userRejected`），但工具根本不会执行。
/// 渲染判据对两者一视同仁，因此覆盖「拒绝」即可。
///
/// ## 顺序要求：先切会话，再选模型
///
/// 模型选择是**按会话**生效的（`ModelSelectionCapabilityAdapter.select`
/// 写的是当前选中会话的 `modelID`），而会话切换是异步的。
/// 因此两个用例都严格按「切会话 → 等选中态生效 → 选模型 → 发消息」的顺序，
/// 否则模型会落到别的会话上，消息走默认模型返回纯文本，
/// 授权卡片自然永远不出现。
///
/// 范式参照 `LumiAskUserUITests` 与 `LumiMessageListSwitchUITests`。
final class LumiToolApprovalSwitchUITests: LumiUITestCase {

    /// 授权卡片的无障碍标识符（复述 `ToolApprovalAccessibility`）。
    ///
    /// 必须按标识符定位：卡片与按钮文案是随 `-AppleLanguages` 变化的
    /// 本地化文本，按文案定位在非英文环境下必然失败。
    private enum Identifiers {
        /// 授权卡片容器。出现即代表有一个待用户处理的授权请求。
        static let card = "lumi.tool-approval.card"
        /// 「拒绝」按钮。
        static let reject = "lumi.tool-approval.reject"
    }

    /// 模型选择器与聊天输入框的标识符。
    private enum Shell {
        static let modelPopover = "lumi.model-selector.popover"
        static let editor = "lumi.conversation-input.editor"
    }

    /// 桩产出的稳定文案与工具锚点。
    private enum Stub {
        /// 用户做出授权决定后，桩在第二轮给出的收尾正文。
        static let followUpResponse = "UI Testing Approval Resolved"
        /// 工具行展示的操作描述里必然出现的文件名。
        ///
        /// `EditFileTool.displayDescription` 产出「编辑 <文件名>」，
        /// 文件名由桩的 `file_path` 参数决定，因此这段文本是稳定的。
        /// 它用于证明「工具行确实被渲染了」——否则「授权卡片不存在」
        /// 可能只是因为整行都没画出来，测试就成了假通过。
        static let toolAnchor = "lumi-ui-test-approval.txt"
    }

    /// 夹具植入的会话标题。
    private enum Conversations {
        static let small = "Switch Target Small"
        static let large = "Switch Target Large"
    }

    // MARK: - Lifecycle

    override func setUpWithError() throws {
        continueAfterFailure = false
        launchLumi(extraArguments: [
            // 确定性 LLM 供应商 + 隔离存储 + 两个可切换的会话。
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

    /// 用户已处理授权 → 切到其他对话 → 切回来 → 授权界面不得再出现。
    ///
    /// 断言分层：
    /// 1. 高风险工具调用弹出授权卡片 → 授权链路本身是通的；
    /// 2. 点「拒绝」后回合以桩收尾正文结束 → 决定确实被受理并回传给模型；
    /// 3. 授权卡片消失 → 处理后当前视图立即不再要求授权；
    /// 4. 切走再切回后工具行仍在（证明不是「行没渲染」的假通过）；
    /// 5. 切回后授权卡片**不**存在 → 这正是用户报告的缺陷判据。
    func testApprovalCardDoesNotReappearAfterSwitchingConversations() throws {
        // 在小会话里跑这一轮：夹具默认选中大会话，切到小会话后消息更少、
        // 列表更浅，断言更稳。
        switchConversation(to: Conversations.small)
        selectStubModel("ui-test-approval")

        let prompt = "UI Testing Approval Probe"
        XCTAssertTrue(
            typeAndSend(prompt, editorIdentifier: Shell.editor),
            "未找到聊天输入框（identifier=\(Shell.editor)）"
        )
        XCTAssertTrue(
            element(anyLabelOf: [prompt]).waitForExistence(timeout: 30),
            "用户消息未出现在时间线上，回合可能未启动"
        )

        // 断言 1：高风险工具的授权卡片出现。
        let card = element(identifier: Identifiers.card)
        if !waitForApprovalCard(card, timeout: 60) {
            XCTFail(
                """
                高风险工具的授权卡片未出现（identifier=\(Identifiers.card)），\
                说明模型未发起工具调用，或工具未被判定为需要授权。\
                当前界面文本：\(visibleTextSummary())
                """
            )
        }

        // 断言 2：点「拒绝」后回合恢复，并以桩收尾正文结束。
        //
        // 桩只有在请求体里看到 `role=tool` 消息（即授权决定确实回传给了
        // 模型）时才会产出这段正文，因此它是「决定已被受理」的确定性证据。
        let reject = element(identifier: Identifiers.reject)
        XCTAssertTrue(
            reject.waitForExistence(timeout: 10),
            "「拒绝」按钮未出现（identifier=\(Identifiers.reject)）"
        )
        reject.click()
        XCTAssertTrue(
            element(anyLabelOf: [Stub.followUpResponse]).waitForExistence(timeout: 60),
            """
            拒绝后未渲染桩收尾回复「\(Stub.followUpResponse)」，\
            说明授权决定未回传给模型或回合未恢复
            """
        )

        // 断言 3：处理完成后授权卡片立即消失。
        XCTAssertTrue(
            waitForNonExistence(card, timeout: 20),
            "处理完授权后授权卡片仍留在界面上"
        )

        // 切走再切回——这正是用户报告的触发路径。
        switchConversation(to: Conversations.large)
        switchConversation(to: Conversations.small)

        // 断言 4：工具行确实被渲染了。
        //
        // 没有这一步，断言 5 就可能是假通过：列表若根本没画出工具行，
        // 「授权卡片不存在」当然成立，但它证明不了任何事。
        XCTAssertTrue(
            element(containingLabel: Stub.toolAnchor).waitForExistence(timeout: 30),
            "切回对话后工具行未渲染，无法据此判断授权卡片是否复活"
        )

        // 断言 5：切回后授权卡片不得复活。
        XCTAssertFalse(
            element(identifier: Identifiers.card).exists,
            """
            切回对话后授权卡片重新出现，尽管用户已经处理过这次授权。\
            授权终态已落库，却被工具结果解析缓存覆盖回「等待授权」的旧快照。
            """
        )
    }

    /// 未处理授权时，授权卡片必须出现。
    ///
    /// 这是上一条的镜像：防止「授权卡片该出现时却不出现」被一起带进来。
    func testApprovalCardAppearsForHighRiskToolCall() throws {
        switchConversation(to: Conversations.small)
        selectStubModel("ui-test-approval")

        let prompt = "UI Testing Approval Present Probe"
        XCTAssertTrue(
            typeAndSend(prompt, editorIdentifier: Shell.editor),
            "未找到聊天输入框（identifier=\(Shell.editor)）"
        )

        if !waitForApprovalCard(element(identifier: Identifiers.card), timeout: 60) {
            XCTFail(
                """
                高风险工具的授权卡片未出现。当前界面文本：\(visibleTextSummary())
                """
            )
        }
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
        // 弹窗关闭后输入框需要重新拿回键盘焦点，否则紧随其后的粘贴会落空。
        sleep(1)
    }

    /// 在会话列表里点击指定标题，并**等切换真正生效**。
    ///
    /// - Important: 等待选中态不是形式主义。模型选择是**按会话**生效的
    ///   （`ModelSelectionCapabilityAdapter.select` 写的是当前选中会话的
    ///   `modelID`，不是全局选择），而会话切换本身是异步的。若在切换
    ///   尚未落定时就选模型，模型会被写到**另一个**会话上；随后发出的
    ///   消息就落到那个会话的默认模型（`ui-test-text`），桩返回纯文本、
    ///   回合秒结束，授权卡片永远不会出现——症状与"授权链路坏了"完全一样，
    ///   却与被测行为毫无关系。
    ///
    /// - Important: 查询必须限定在**列表容器内**（`listID`）。会话标题在
    ///   消息列表正文里也可能出现同名文本，全窗口搜索会命中消息正文而非
    ///   会话行，点击后选中态不变，表现为「切换没生效」，极具误导性。
    private func switchConversation(to title: String) {
        let row = conversationRow(title)
        XCTAssertTrue(
            row.waitForExistence(timeout: 15),
            "会话「\(title)」在列表中不可见（列表容器内未找到）"
        )
        row.click()

        // 会话行用 isSelected 特性表达"当前选中"（见 ConversationListAccessibility）。
        // 等它变为选中，才算切换完成。
        //
        // - Note: 这里直接读 XCUIElement 的 `isSelected` 属性而不是写
        //   `NSPredicate(format: "isSelected == true")`：后者依赖 KVC 键名，
        //   键名不对时谓词求值会直接抛异常，症状与"切换失败"无关，很难归因。
        var becameSelected = false
        for _ in 0..<40 {
            if row.exists, row.isSelected {
                becameSelected = true
                break
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTAssertTrue(
            becameSelected,
            "点击后会话「\(title)」未变为选中态，切换未生效"
        )
    }

    /// 定位一条会话行：限定列表容器 → 按 item 标识筛出所有行 → 按 label 匹配标题。
    ///
    /// - Note: 会话列表的标识符常量复用 `LumiConversationListIDs`
    ///   （声明于 `LumiMessageListSwitchUITests.swift`，同一 target 内共用）。
    private func conversationRow(_ title: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: LumiConversationListIDs.listID)
            .descendants(matching: .any)
            .matching(identifier: LumiConversationListIDs.itemID)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", title, title))
            .firstMatch
    }

    /// 等待授权卡片出现。
    ///
    /// 单独抽出来是为了让「没等到卡片」时的失败信息带上当时的界面文本：
    /// 若看到的是桩的纯文本回复，说明**用错了模型**（模型按会话生效，
    /// 切换会话没落定就选模型会写到别的会话上），而不是授权链路有问题——
    /// 这两种失败的现象完全一样，光看断言无法区分。
    private func waitForApprovalCard(_ card: XCUIElement, timeout: TimeInterval) -> Bool {
        card.waitForExistence(timeout: timeout)
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
