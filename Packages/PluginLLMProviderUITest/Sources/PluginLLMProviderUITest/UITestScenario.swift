import Foundation
import KitLLM

/// UI 测试供应商的场景模型清单。
///
/// ## 设计：模型名承载行为
///
/// 本供应商不为每个测试场景注册一个供应商，而是让**模型名本身决定桩的行为**。
/// 测试通过「选中哪个模型」来控制 App 的对话行为，夹具的复杂度因此不随场景数增长，
/// 单一启动参数 `--lumi-ui-testing` 即可覆盖全部场景。
///
/// 这与真实供应商的用法完全一致：测试点模型选择器 → 选中 `ui-test-error`
/// 就得到一个确定失败的回合，不需要任何测试专属的 UI 分支。
///
/// ## 新增场景的方式
///
/// 在 `UITestScenario` 上加一个 case，并在此清单登记模型元数据。不需要改动
/// 插件装配、桩网络或任何生产代码。
enum UITestScenario: String, CaseIterable, Sendable {
    /// 固定文本回复，分 3 个 SSE 事件增量吐出。用于验证正常回合的渲染。
    case text = "ui-test-text"

    /// 返回一个工具调用。用于验证工具执行链路与工具结果回传。
    case tool = "ui-test-tool"

    /// 抛错。用于验证错误消息渲染与「重试该回合」按钮。
    case error = "ui-test-error"

    /// 每段之间 sleep。用于验证流式加载态。
    case slow = "ui-test-slow"

    /// 超长回合：段落数远多于 `slow`，且段间同样 sleep。
    ///
    /// 存在理由：`slow` 实测端到端仅约 1.7s（3 段 × 0.4s + 首包往返），
    /// 而 XCUITest 单次状态查询本身就要几百毫秒。要稳定观察「回合中」的
    /// 界面状态（停止按钮是否**持续**存在、能否在回合中点击停止），
    /// 回合窗口必须显著长于 UI 测试的轮询周期，否则测的是运气不是行为。
    ///
    /// 本场景把回合拉到十几秒量级，让「回合中」成为一个可稳定采样的状态。
    case verySlow = "ui-test-very-slow"

    /// 长文本回复。用于验证滚动与消息列表虚拟化。
    case long = "ui-test-long"

    /// 调用 `ask_user`（yes_no 模式）后挂起等待回答。用于验证交互式提问的完整链路。
    ///
    /// 首轮返回 `ask_user` 工具调用 → 回合挂起 → 用户点选 → 第二轮返回
    /// 收尾文本。两段式响应见 `UITestStubNetwork.askUserEvents(for:alreadyAnswered:)`。
    case askUserYesNo = "ui-test-ask-user-yes-no"

    /// 同上，但 `mode="choice"`，带多个选项（含 description / badge）。
    case askUserChoice = "ui-test-ask-user-choice"

    /// 同 `askUserYesNo`，但**恢复后的第二轮**被拉长成多段慢响应。
    ///
    /// 存在理由：用户回答提问后，回合进入「恢复中」——AgentLoop 在跑，但会话
    /// 状态快照还没收到新事件，仍停留在 `.suspended`。这个窗口必须能被稳定
    /// 观测，否则「恢复回合中按停止是否真的停得住」只能靠运气。
    case askUserYesNoSlow = "ui-test-ask-user-yes-no-slow"

    /// 同上，但 `mode="free_text"`，无选项，走输入框 + 提交按钮。
    case askUserFreeText = "ui-test-ask-user-free-text"

    /// 调用**高风险工具**（`edit_file`）后挂起等待授权。用于验证高风险工具
    /// 的授权卡片与「授权已处理后不再重复弹」的回归。
    ///
    /// 首轮返回 `edit_file` 工具调用 → 回合挂起 → 界面弹出授权卡片；
    /// 用户点「允许/拒绝」后第二轮返回固定收尾正文。
    /// 两段式响应与 ask_user 场景共用同一判据（请求体里是否已有
    /// `role=tool` 消息），见 `UITestStubNetwork.hasToolResult`。
    case approval = "ui-test-approval"

    /// 未知模型时的默认场景，保证不返回意外结果。
    case unknown = "ui-test-unknown"

    /// 该场景对应的模型元数据。
    var model: LLMModelInfo {
        LLMModelInfo(
            id: rawValue,
            displayName: displayName,
            contextWindowSize: 128_000,
            supportsStreaming: true,
            supportsVision: false,
            // ask_user 是工具调用场景，必须声明支持工具，否则请求体里不会带 tools。
            supportsTools: self == .tool || self.isAskUser || self == .text || self == .approval
        )
    }

    /// 是否为 ask_user 交互场景。
    var isAskUser: Bool {
        switch self {
        case .askUserYesNo, .askUserChoice, .askUserFreeText, .askUserYesNoSlow: return true
        default: return false
        }
    }

    /// 是否为高风险工具授权场景。
    var isApproval: Bool {
        self == .approval
    }

    /// 该场景发起的 `ask_user` 工具调用参数 JSON。
    ///
    /// 字段与 `AskUserTool.inputSchema` 保持一致；桩与真实模型一样，
    /// 只按 schema 产出参数，不假设宿主如何解析。
    var askUserArguments: String? {
        switch self {
        case .askUserYesNo, .askUserYesNoSlow:
            return #"{"question":"\#(UITestFixtures.askUserYesNoQuestion)","mode":"yes_no"}"#
        case .askUserChoice:
            return UITestFixtures.askUserChoiceArguments
        case .askUserFreeText:
            return #"{"question":"\#(UITestFixtures.askUserFreeTextQuestion)","mode":"free_text"}"#
        default:
            return nil
        }
    }

    /// 该场景在「用户已回答」后产出的收尾正文。
    ///
    /// 慢恢复场景用不同的正文：它需要被拆成多段慢速吐出，
    /// UI 测试才能在「恢复回合中」这个窗口里稳定采样。
    var askUserFollowUpResponse: String {
        switch self {
        case .askUserYesNoSlow: return UITestFixtures.slowResumeFollowUpResponse
        default: return UITestFixtures.askUserFollowUpResponse
        }
    }

    /// 面向用户的展示名（模型选择器里可见，便于测试按名字定位）。
    var displayName: String {
        switch self {
        case .text: return "UI Test Text"
        case .tool: return "UI Test Tool"
        case .error: return "UI Test Error"
        case .slow: return "UI Test Slow"
        case .verySlow: return "UI Test Very Slow"
        case .long: return "UI Test Long"
        case .askUserYesNo: return "UI Test Ask User Yes No"
        case .askUserYesNoSlow: return "UI Test Ask User Yes No Slow"
        case .askUserChoice: return "UI Test Ask User Choice"
        case .askUserFreeText: return "UI Test Ask User Free Text"
        case .approval: return "UI Test Approval"
        case .unknown: return "UI Test Unknown"
        }
    }

    /// 全部场景模型，按声明顺序。默认模型固定为 `.text`。
    static var allModels: [LLMModelInfo] {
        allCases.map(\.model)
    }

    /// 默认模型：固定文本回复，最常用也最安全。
    ///
    /// 选它做默认值是因为它是唯一一个「无论如何都会成功结束」的场景——
    /// 未显式指定模型的请求（如新建会话）落到它身上时不会意外失败。
    static let defaultModel = UITestScenario.text
}

/// UI 测试可依赖的稳定常量。
///
/// 这些字符串同时出现在桩的输出与 UI 测试的断言里，因此集中定义：
/// 桩改了文案而测试没改（或反之），测试会以「断言失败」的形式明确暴露，
/// 而不是静默地等一个永远不出现的文本。
enum UITestFixtures {
    /// 文本场景的完整回复正文。
    ///
    /// 分 3 段吐出，拼接后必须严格等于本字符串。
    static let textResponse = "UI Testing Reply"

    /// 文本场景的分段（拼接结果为 `textResponse`）。
    static let textChunks = ["UI Testing ", "Reply", ""]

    /// 长文本场景的段落数（每段一句，总长度足以撑开一屏）。
    static let longParagraphCount = 40

    /// 工具场景调用的工具名。
    ///
    /// 与 AgentLoop 实际下发的工具名无关：真实工具名会先经过
    /// `LLMToolNameSanitizer` 处理，而桩返回的是未经处理的原名，
    /// 由 `VendorLLMProvider` 的 reverseMap 还原——这正是要被覆盖的路径。
    static let toolName = "list_files"

    /// 工具调用的参数 JSON。
    static let toolArguments = #"{"path":"."}"#

    /// 工具场景在工具执行后第二轮的收尾回复。
    static let toolFollowUpResponse = "UI Testing Tool Done"

    /// 错误场景的失败原因，出现在 error 消息正文里。
    static let errorMessage = "UI Testing Request Failed"

    // MARK: - ask_user 场景

    /// ask_user 工具名。
    ///
    /// 与 `AskUserTool.toolName` 一致。桩返回未经 sanitize 的原名，
    /// 由 `VendorLLMProvider` 的 reverseMap 还原成注册名。
    static let askUserToolName = "ask_user"

    /// ask_user 首轮工具调用的 id。
    static let askUserToolCallID = "call_ui_test_ask_user"

    /// yes_no 场景的问题文案。
    static let askUserYesNoQuestion = "UI Testing Continue?"

    /// choice 场景的问题文案。
    static let askUserChoiceQuestion = "UI Testing Pick One"

    /// free_text 场景的问题文案。
    static let askUserFreeTextQuestion = "UI Testing Describe Next Step"

    /// choice 场景的工具参数。
    ///
    /// 第二个选项刻意带上 `badge`，让 UI 测试能覆盖「带徽标的选项」这一渲染分支；
    /// 第一个选项带 `description`，覆盖说明文案的渲染分支。
    ///
    /// - Note: 必须拼成**单行** JSON。多行字符串字面量的 `\` 续行会在
    ///   换行处留下空格，产出带空白的 JSON 仍可解析，但缩进会在
    ///   `"label"` 前留下空格导致拼接后的 arguments 含非法转义。
    static let askUserChoiceArguments =
        #"{"question":"\#(askUserChoiceQuestion)","mode":"choice","options":[{"label":"\#(askUserChoiceOptionAccepted)","description":"\#(askUserChoiceOptionAcceptedDescription)"},{"label":"\#(askUserChoiceOptionRejected)","badge":"\#(askUserChoiceOptionRejectedBadge)"}]}"#

    /// choice 场景第一个选项（UI 测试点击它）。
    static let askUserChoiceOptionAccepted = "UI Testing Accept"

    /// choice 场景第一个选项的说明文本。
    static let askUserChoiceOptionAcceptedDescription = "Accept and continue"

    /// choice 场景第二个选项。
    static let askUserChoiceOptionRejected = "UI Testing Reject"

    /// choice 场景第二个选项的徽标。
    static let askUserChoiceOptionRejectedBadge = "Fast"

    /// 用户回答后，桩在第二轮给出的收尾回复。
    ///
    /// 这是「答案确实回传给了 LLM 并被接受」的确定性证据：
    /// 桩只有在请求体里看到 `role=tool` 的消息（即用户已回答）时才产出它。
    static let askUserFollowUpResponse = "UI Testing Ask User Answered"

    /// 慢恢复场景的收尾正文。
    ///
    /// 与 `askUserFollowUpResponse` 分开：慢恢复场景要在恢复窗口里
    /// 持续产出内容，UI 测试才能断言「回合还在跑」而不是「已经跑完了」。
    static let slowResumeFollowUpResponse = "UI Testing Slow Resumed Turn"

    /// 慢恢复场景的段数。
    ///
    /// 与 `slowChunkDelay` 相乘约 6s（16 × 0.4s），给 XCUITest 留出足够的
    /// 采样与点击窗口。
    static let slowResumeChunkCount = 16

    // MARK: - 高风险工具授权场景

    /// 授权场景调用的工具名。
    ///
    /// 与 `EditFileTool.toolName` 一致。`EditFileTool.permissionRiskLevel`
    /// 恒为 `.high`（`requiresPermission == true`），因此桩发出这个调用
    /// 必然触发用户授权流程。
    static let approvalToolName = "edit_file"

    /// 授权场景的工具调用 id。
    static let approvalToolCallID = "call_ui_test_approval"

    /// 授权场景的工具参数。
    ///
    /// 参数只需要能被 `ToolArgumentCoding` 解码即可——授权卡片的判据是
    /// 工具的**风险等级**，与参数内容无关。UI 测试点的是「拒绝」，
    /// 工具不会被执行，因此不会真的去改这个文件。
    static let approvalToolArguments =
        #"{"file_path":"/tmp/lumi-ui-test-approval.txt","old_string":"before","new_string":"after"}"#

    /// 授权场景在用户做出决定后，桩在第二轮给出的收尾回复。
    ///
    /// 判据与 ask_user 场景相同：请求体里出现 `role=tool` 消息
    /// （即用户的授权决定已回传给模型）时才产出。
    static let approvalFollowUpResponse = "UI Testing Approval Resolved"

    /// 慢速场景每段之间的延迟（秒）。
    static let slowChunkDelay: Double = 0.4

    /// 超长回合场景的段数。
    ///
    /// 与 `slowChunkDelay` 相乘约 12s（32 × 0.4s），使回合窗口
    /// 显著长于 XCUITest 的单次状态查询耗时。
    static let verySlowParagraphCount = 32
}
