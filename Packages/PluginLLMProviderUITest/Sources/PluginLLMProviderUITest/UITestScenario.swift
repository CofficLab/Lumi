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

    /// 长文本回复。用于验证滚动与消息列表虚拟化。
    case long = "ui-test-long"

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
            supportsTools: self == .tool || self == .text
        )
    }

    /// 面向用户的展示名（模型选择器里可见，便于测试按名字定位）。
    var displayName: String {
        switch self {
        case .text: return "UI Test Text"
        case .tool: return "UI Test Tool"
        case .error: return "UI Test Error"
        case .slow: return "UI Test Slow"
        case .long: return "UI Test Long"
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

    /// 慢速场景每段之间的延迟（秒）。
    static let slowChunkDelay: Double = 0.4
}
