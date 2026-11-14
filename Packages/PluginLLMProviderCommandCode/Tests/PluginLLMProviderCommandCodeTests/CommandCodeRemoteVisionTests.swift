import Foundation
import KitLLM
import Testing
@testable import PluginLLMProviderCommandCode

/// 远程模型刷新不得清掉静态基线声明的 Vision 能力（#366）。
///
/// ## 为什么要有这条测试
///
/// 远程解析器只读取 `id/name/context_length`，构造 `LLMModelInfo` 时
/// `supportsVision` 走默认值 `false`。合并同 id 模型时若整体替换静态条目，
/// 静态声明的 `supportsVision=true`（如 `deepseek/deepseek-v4.1-flash`）
/// 会被远程的 `false` 顶掉，模型随即从 Vision 分类里消失。
///
/// 合并必须保留静态能力：远程未提供能力字段时，`supportsVision` 取
/// `remote || base`，只更新远程实际给出的名称/窗口等元数据。
@Suite("CommandCode 远程刷新保留静态 Vision 能力")
struct CommandCodeRemoteVisionTests {

    private func parse(_ json: String) throws -> [LLMModelInfo] {
        try RemoteModelListLoader.parse(data: Data(json.utf8))
    }

    private var visionBaseline: [LLMModelInfo] {
        [LLMModelInfo(
            id: "deepseek/deepseek-v4.1-flash",
            displayName: "DeepSeek V4.1 Flash",
            contextWindowSize: 1_000_000,
            supportsVision: true
        )]
    }

    @Test("远程刷新（带窗口）保留静态 Vision 能力")
    func remoteRefreshPreservesStaticVision() throws {
        let remote = try parse("""
        {"data":[{"id":"deepseek/deepseek-v4.1-flash","name":"DeepSeek V4.1 Flash","context_length":1000000}]}
        """)

        let merged = RemoteModelMerger.merge(base: visionBaseline, remote: remote)
        let model = try #require(merged.first(where: { $0.id == "deepseek/deepseek-v4.1-flash" }))

        #expect(
            model.supportsVision == true,
            "远程未提供能力字段时必须保留静态 Vision，实际 \(model.supportsVision)"
        )
        #expect(model.contextWindowSize == 1_000_000)
    }

    @Test("远程刷新（缺窗口）仍保留静态 Vision 能力与窗口")
    func remoteWithoutWindowPreservesStaticVision() throws {
        let remote = try parse("""
        {"data":[{"id":"deepseek/deepseek-v4.1-flash","name":"DeepSeek V4.1 Flash"}]}
        """)

        let merged = RemoteModelMerger.merge(base: visionBaseline, remote: remote)
        let model = try #require(merged.first(where: { $0.id == "deepseek/deepseek-v4.1-flash" }))

        #expect(model.supportsVision == true)
        #expect(model.contextWindowSize == 1_000_000)
    }

    @Test("非 Vision 静态模型合并后不会误报 Vision")
    func nonVisionModelStaysNonVisionAfterMerge() throws {
        let base = [LLMModelInfo(id: "claude-sonnet-5", contextWindowSize: 1_000_000)]
        let remote = try parse("""
        {"data":[{"id":"claude-sonnet-5","name":"Claude Sonnet 5","context_length":1000000}]}
        """)

        let merged = RemoteModelMerger.merge(base: base, remote: remote)
        let model = try #require(merged.first(where: { $0.id == "claude-sonnet-5" }))

        #expect(model.supportsVision == false)
    }
}