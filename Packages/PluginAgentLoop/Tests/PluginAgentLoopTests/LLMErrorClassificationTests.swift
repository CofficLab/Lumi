import Foundation
import KitLLM
import ProviderConversation
import ProviderLLMContext
import ProviderLLMManager
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager
import Testing
@testable import PluginAgentLoop

/// `AgentLoopManager` 中三个纯判断/估算函数的直接覆盖。
///
/// 这些函数此前只能通过「让桩 LLM 抛错」间接触发，主路径之外的分支
/// （认证失败、空响应、非法 base64 摘要、参数无法序列化）从未被执行。
@MainActor
@Suite("LLM 错误分类与工具 schema 估算")
struct LLMErrorClassificationTests {

    // MARK: - Fixtures

    /// 这三个函数不触碰任何状态，构造一个最小 manager 即可。
    private func makeManager() -> AgentLoopManager {
        let messages = DefaultMessageManager()
        return AgentLoopManager(
            messages: messages,
            llmManager: DefaultLLMManager(),
            toolManager: DefaultToolManagerProviding(),
            streaming: DefaultMessageStreamingProviding(),
            conversations: DefaultConversationManager(),
            contextProvider: PassthroughLLMContextProvider(messages: messages)
        )
    }

    // MARK: - isRecoverableLLMFailure

    /// 工具协议错误可重试：它不改变用户任务本身，同一回合重发即可。
    @Test("工具调用参数非法视为可恢复")
    func toolCallValidationErrorIsRecoverable() {
        let manager = makeManager()
        let error = LLMToolCallValidationError.invalidArguments(
            toolCallID: "call_1",
            toolName: "run_command"
        )

        #expect(manager.isRecoverableLLMFailure(error))
    }

    /// 流式中断与解码失败都是传输层抖动，重试可能成功。
    @Test("流式中断与解码失败视为可恢复")
    func transportFailuresAreRecoverable() {
        let manager = makeManager()

        #expect(manager.isRecoverableLLMFailure(VendorAPIError.incompleteStream))
        #expect(manager.isRecoverableLLMFailure(VendorAPIError.decodingFailed("bad json")))
    }

    /// 认证/配置类错误重试必然再次失败，必须立即终止回合。
    @Test("认证与配置类错误不可恢复")
    func configurationFailuresAreNotRecoverable() {
        let manager = makeManager()

        #expect(!manager.isRecoverableLLMFailure(VendorAPIError.missingAPIKey("openai")))
        #expect(!manager.isRecoverableLLMFailure(VendorAPIError.apiKeyAccessFailed(
            provider: "openai",
            details: "keychain locked"
        )))
        #expect(!manager.isRecoverableLLMFailure(VendorAPIError.invalidBaseURL("not a url")))
        #expect(!manager.isRecoverableLLMFailure(VendorAPIError.emptyResponse))
        #expect(!manager.isRecoverableLLMFailure(VendorAPIError.requestFailed("timeout")))
    }

    /// HTTP 错误即便摘要含 "context"，也走 `isContextLimitError` 的独立判断，
    /// 绝不能顺带被判成可恢复——否则超限会被无限重试。
    @Test("HTTP 错误一律不可恢复，即使摘要含 context")
    func httpStatusIsNeverRecoverable() {
        let manager = makeManager()

        #expect(!manager.isRecoverableLLMFailure(VendorAPIError.httpStatus(400, "context length exceeded")))
        #expect(!manager.isRecoverableLLMFailure(VendorAPIError.httpStatus(429, "rate limit")))
    }

    /// 非 VendorAPIError 的未知错误不得被乐观重试。
    @Test("未知错误类型不可恢复")
    func unknownErrorIsNotRecoverable() {
        struct Boom: Error {}
        let manager = makeManager()

        #expect(!manager.isRecoverableLLMFailure(Boom()))
        #expect(!manager.isRecoverableLLMFailure(CancellationError()))
    }

    // MARK: - isContextLimitError

    /// 五种措辞都必须识别，否则超限后不会触发压缩重试而直接失败。
    @Test("各种上下文超限措辞都能被识别")
    func contextLimitPhrasesAreDetected() {
        let manager = makeManager()
        let phrases = [
            "context length exceeded",
            "maximum context length is 8192 tokens",
            "token limit reached",
            "too many tokens in prompt",
            "prompt is too long"
        ]

        for phrase in phrases {
            #expect(
                manager.isContextLimitError(VendorAPIError.httpStatus(400, phrase)),
                "未识别超限措辞：\(phrase)"
            )
        }
    }

    /// 判断基于小写化，供应商返回大写摘要也必须命中。
    @Test("超限判断忽略大小写")
    func contextLimitDetectionIsCaseInsensitive() {
        let manager = makeManager()

        #expect(manager.isContextLimitError(VendorAPIError.httpStatus(400, "CONTEXT LENGTH EXCEEDED")))
        #expect(manager.isContextLimitError(VendorAPIError.httpStatus(400, "Prompt Is Too Long")))
    }

    /// 与超限无关的 HTTP 错误不得触发压缩重试。
    @Test("无关的 HTTP 错误不算超限")
    func unrelatedHTTPErrorsAreNotContextLimit() {
        let manager = makeManager()

        #expect(!manager.isContextLimitError(VendorAPIError.httpStatus(401, "invalid api key")))
        #expect(!manager.isContextLimitError(VendorAPIError.httpStatus(500, "internal server error")))
    }

    /// 非 httpStatus 的错误一律不是超限（guard 直接返回 false）。
    @Test("非 HTTP 错误不算超限")
    func nonHTTPErrorsAreNotContextLimit() {
        let manager = makeManager()

        #expect(!manager.isContextLimitError(VendorAPIError.incompleteStream))
        #expect(!manager.isContextLimitError(VendorAPIError.emptyResponse))
        #expect(!manager.isContextLimitError(VendorAPIError.missingAPIKey("openai")))
        #expect(!manager.isContextLimitError(LLMToolCallValidationError.invalidArguments(
            toolCallID: "c",
            toolName: "t"
        )))
    }

    /// 两个判定必须互相独立：认证错误既不可恢复，也不是超限。
    @Test("超限判断与可恢复判断互不干扰")
    func contextLimitAndRecoverableAreIndependent() {
        let manager = makeManager()
        let contextError = VendorAPIError.httpStatus(400, "maximum token limit exceeded")

        #expect(manager.isContextLimitError(contextError))
        #expect(!manager.isRecoverableLLMFailure(contextError))
    }

    // MARK: - estimateToolSchemaTokens

    /// 空 schema 列表不应凭空产生开销。
    @Test("没有工具时估算为 0")
    func estimateIsZeroForEmptySchemas() {
        let manager = makeManager()

        #expect(manager.estimateToolSchemaTokens([]) == 0)
    }

    /// 每个 schema 的估算 = 名称 + 描述 + 参数 JSON + 16 固定开销，且可累加。
    @Test("工具 schema 估算等于各部分之和且可累加")
    func estimateSumsNameDescriptionParametersAndOverhead() {
        let manager = makeManager()
        let schema = LLMFunctionSchema(
            name: "run_command",
            description: "在项目目录执行一条 shell 命令",
            parameters: ["type": "object", "properties": ["command": ["type": "string"]]]
        )

        let actual = manager.estimateToolSchemaTokens([schema])

        // 参数走 JSONSerialization 的 .sortedKeys 序列化，键序确定。
        let parametersJSON = #"{"properties":{"command":{"type":"string"}},"type":"object"}"#
        let expected = LLMContextTokenEstimator.estimate(text: schema.name)
            + LLMContextTokenEstimator.estimate(text: schema.description)
            + LLMContextTokenEstimator.estimate(text: parametersJSON)
            + 16
        #expect(actual == expected)
    }

    /// 多个 schema 的估算等于各自估算之和。
    @Test("多个工具的估算等于单工具估算之和")
    func estimateAccumulatesAcrossSchemas() {
        let manager = makeManager()
        let first = LLMFunctionSchema(name: "ls", description: "列目录", parameters: ["type": "object"])
        let second = LLMFunctionSchema(name: "read_file", description: "读取文件", parameters: ["type": "object"])

        let combined = manager.estimateToolSchemaTokens([first, second])
        let separate = manager.estimateToolSchemaTokens([first]) + manager.estimateToolSchemaTokens([second])

        #expect(combined == separate)
        #expect(combined > 0)
    }

    /// 回归测试：畸形参数曾经让整个进程 abort（signal 6）。
    ///
    /// `JSONSerialization.data(withJSONObject:)` 对非 JSON 类型抛的是 ObjC
    /// `NSException`，`try?` 捕获不到，原实现会崩。这里锁定「必须降级为
    /// 文本估算」的行为——该用例在修复前会导致测试进程直接退出。
    @Test("参数无法序列化时降级为文本估算而不崩溃")
    func estimateFallsBackWhenParametersAreNotSerializable() {
        let manager = makeManager()
        let schemas = [
            LLMFunctionSchema(name: "closure_tool", description: "闭包参数", parameters: ["closure": { }]),
            LLMFunctionSchema(name: "date_tool", description: "日期参数", parameters: ["date": Date()]),
            LLMFunctionSchema(name: "data_tool", description: "二进制参数", parameters: ["data": Data([0x01])]),
            LLMFunctionSchema(name: "nan_tool", description: "NaN 参数", parameters: ["value": Double.nan])
        ]

        for schema in schemas {
            let tokens = manager.estimateToolSchemaTokens([schema])
            #expect(tokens > 0, "畸形参数应降级为正数估算：\(schema.name)")
        }
    }

    /// 畸形 schema 与正常 schema 混在一批工具里时，
    /// 畸形项不得影响其它项的估算，批次整体仍可用。
    @Test("畸形工具不影响同批次其它工具的估算")
    func malformedSchemaDoesNotBreakBatchEstimation() {
        let manager = makeManager()
        let healthy = LLMFunctionSchema(name: "ls", description: "列目录", parameters: ["type": "object"])
        let broken = LLMFunctionSchema(name: "broken", description: "畸形", parameters: ["closure": { }])

        let mixed = manager.estimateToolSchemaTokens([healthy, broken])
        let healthyOnly = manager.estimateToolSchemaTokens([healthy])

        #expect(mixed > healthyOnly)
        #expect(mixed >= healthyOnly + 16)
    }

    /// 空名称与空描述也按最小 1 token 计入，保证估算不会归零。
    @Test("空名称与描述仍计入固定开销")
    func estimateAlwaysIncludesFixedOverhead() {
        let manager = makeManager()
        let empty = LLMFunctionSchema(name: "", description: "", parameters: [:])

        // 名称/描述/参数各至少 1 token，再加 16 固定开销。
        #expect(manager.estimateToolSchemaTokens([empty]) >= 19)
    }
}
