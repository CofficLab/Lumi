import Foundation
import KitLLM
import Testing
@testable import PluginLLMProviderCommandCode

/// CommandCode 远程模型列表里的上下文窗口必须是正数。
///
/// ## 为什么要有这条测试
///
/// 远程解析器此前把 `context_length` 直接 `intValue` 后交给
/// `LLMModelInfo`，`0` 与负数都会被当成有效值发布。合并时远程条目会
/// **整体替换**同 id 的静态条目，于是一个畸形的远程 `0` 会顶掉有效的
/// 静态窗口（如 1,000,000）。
///
/// 更糟的是该值非 `nil`，于是「窗口未知」的兜底分支不会生效：预算层
/// 只把有效窗口钳到 4096，输入上限随之塌到 1024 token，普通历史就被
/// 压缩或确定性截断。畸形远程值绝不能压垮生产输入预算。
@Suite("CommandCode 远程上下文窗口校验")
struct CommandCodeRemoteContextWindowTests {

    private func parse(_ json: String) throws -> [LLMModelInfo] {
        try RemoteModelListLoader.parse(data: Data(json.utf8))
    }

    // MARK: - 解析

    @Test("正的 context_length 被正常保留")
    func positiveContextLengthIsKept() throws {
        let models = try parse("""
        {"data":[{"id":"claude-sonnet-5","name":"Claude Sonnet 5","context_length":1000000}]}
        """)

        let model = try #require(models.first)
        #expect(model.contextWindowSize == 1_000_000)
    }

    @Test("context_length 为 0 时规范化为 nil（未知窗口）")
    func zeroContextLengthBecomesNil() throws {
        let models = try parse("""
        {"data":[{"id":"claude-sonnet-5","name":"Claude Sonnet 5","context_length":0}]}
        """)

        let model = try #require(models.first)
        #expect(
            model.contextWindowSize == nil,
            "非正的上下文窗口必须视为未知，实际 \(String(describing: model.contextWindowSize))"
        )
    }

    @Test("context_length 为负数时规范化为 nil（未知窗口）")
    func negativeContextLengthBecomesNil() throws {
        let models = try parse("""
        {"data":[{"id":"claude-sonnet-5","name":"Claude Sonnet 5","context_length":-4096}]}
        """)

        let model = try #require(models.first)
        #expect(
            model.contextWindowSize == nil,
            "负的上下文窗口必须视为未知，实际 \(String(describing: model.contextWindowSize))"
        )
    }

    @Test("camelCase 的 contextLength 同样被校验")
    func camelCaseContextLengthIsValidated() throws {
        let models = try parse("""
        {"data":[{"id":"claude-sonnet-5","contextLength":0}]}
        """)

        let model = try #require(models.first)
        #expect(model.contextWindowSize == nil)
    }

    @Test("缺失 context_length 时保持未知窗口")
    func missingContextLengthStaysNil() throws {
        let models = try parse("""
        {"data":[{"id":"claude-sonnet-5","name":"Claude Sonnet 5"}]}
        """)

        let model = try #require(models.first)
        #expect(model.contextWindowSize == nil)
    }

    // MARK: - 合并

    @Test("畸形的远程窗口不会顶掉有效的静态基线")
    func malformedRemoteDoesNotOverrideValidBaseline() throws {
        let base = [LLMModelInfo(id: "claude-sonnet-5", contextWindowSize: 1_000_000)]
        // 远程解析器已把非正值规范化为 nil。
        let remote = try parse("""
        {"data":[{"id":"claude-sonnet-5","name":"Claude Sonnet 5","context_length":0}]}
        """)

        let merged = RemoteModelMerger.merge(base: base, remote: remote)
        let model = try #require(merged.first)

        #expect(
            model.contextWindowSize == 1_000_000,
            "远程畸形值不应覆盖有效的静态窗口，实际 \(String(describing: model.contextWindowSize))"
        )
    }

    @Test("远程条目缺失窗口时仍保留静态基线的窗口")
    func remoteWithoutWindowKeepsBaselineWindow() throws {
        let base = [LLMModelInfo(id: "claude-sonnet-5", contextWindowSize: 1_000_000)]
        let remote = try parse("""
        {"data":[{"id":"claude-sonnet-5","name":"Claude Sonnet 5"}]}
        """)

        let merged = RemoteModelMerger.merge(base: base, remote: remote)
        let model = try #require(merged.first)

        #expect(model.contextWindowSize == 1_000_000)
    }
}
