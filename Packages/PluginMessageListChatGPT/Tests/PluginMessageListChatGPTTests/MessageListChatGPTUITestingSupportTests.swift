import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginMessageListChatGPT

/// V5（ChatGPT）UI 测试夹具契约测试。
///
/// - Important: 夹具必须
///   1. **只在** `--lumi-ui-testing` 与 `--lumi-ui-testing-message-list-chatgpt`
///      同时存在时生效（缺少 `--lumi-ui-testing` 时拒绝启动，
///      防止 UI 测试误连真实供应商）；
///   2. **确定性**：5 个固定会话的内容、顺序、时间戳都可预测；
///   3. **隔离**：不写用户真实数据、不触发真实付费请求；
///   4. **幂等**：重复 seed 不会产生第二份夹具。
@Suite("V5 UI 测试夹具")
@MainActor
struct MessageListChatGPTUITestingSupportTests {

    // MARK: - 启动参数

    @Test("启动参数名固定")
    func launchArgumentName() {
        #expect(
            MessageListChatGPTUITestingSupport.launchArgument
                == "--lumi-ui-testing-message-list-chatgpt"
        )
    }

    @Test("缺少 --lumi-ui-testing 时拒绝启用")
    func requiresGlobalUITestingArgument() {
        #expect(
            MessageListChatGPTUITestingSupport.isEnabled(
                arguments: ["--lumi-ui-testing-message-list-chatgpt"]
            ) == false
        )
    }

    @Test("缺少 V5 专用参数时拒绝启用")
    func requiresChatGPTArgument() {
        #expect(
            MessageListChatGPTUITestingSupport.isEnabled(
                arguments: ["--lumi-ui-testing"]
            ) == false
        )
    }

    @Test("两个参数齐备时启用")
    func enabledWithBothArguments() {
        #expect(
            MessageListChatGPTUITestingSupport.isEnabled(arguments: [
                "--lumi-ui-testing",
                "--lumi-ui-testing-message-list-chatgpt",
            ])
        )
    }

    @Test("隔离存储参数不影响启用判定")
    func isolatedStorageArgumentIsOptional() {
        #expect(
            MessageListChatGPTUITestingSupport.isEnabled(arguments: [
                "--lumi-ui-testing",
                "--lumi-ui-testing-message-list-chatgpt",
                "--lumi-ui-testing-isolated-storage",
            ])
        )
    }

    // MARK: - 会话定义

    @Test("恰好 5 个固定会话")
    func exactlyFiveConversations() {
        #expect(MessageListChatGPTUITestingSupport.fixtureTitles.count == 5)
    }

    @Test("会话标题互不相同")
    func titlesAreDistinct() {
        let titles = MessageListChatGPTUITestingSupport.fixtureTitles
        #expect(Set(titles).count == titles.count)
    }

    @Test("会话标题非空")
    func titlesAreNonEmpty() {
        for title in MessageListChatGPTUITestingSupport.fixtureTitles {
            #expect(!title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @Test("会话标题稳定不变")
    func titlesAreStable() {
        // 夹具标题是 UI 测试的定位锚点，任何改动都会让既有测试失效。
        #expect(MessageListChatGPTUITestingSupport.fixtureTitles == [
            "ChatGPT Visual Target",
            "ChatGPT Reasoning Target",
            "ChatGPT Tool Target",
            "ChatGPT Scroll Target",
            "ChatGPT Error Target",
        ])
    }

    // MARK: - 确定性

    @Test("基准时间是固定的")
    func baseDateIsFixed() {
        #expect(
            MessageListChatGPTUITestingSupport.baseDate
                == Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    @Test("视觉会话正文确定")
    func visualContentIsDeterministic() {
        let first = MessageListChatGPTUITestingSupport.visualUserContent
        let second = MessageListChatGPTUITestingSupport.visualUserContent

        #expect(first == second)
        #expect(!first.isEmpty)
    }

    @Test("助手正文包含 Markdown 列表，用于验证阅读列")
    func assistantContentHasMarkdown() {
        let content = MessageListChatGPTUITestingSupport.visualAssistantContent
        #expect(content.contains("1."))
        #expect(content.contains("\n"))
    }

    @Test("滚动会话的轮数固定")
    func scrollTurnCountIsFixed() {
        #expect(MessageListChatGPTUITestingSupport.scrollTurnCount == 30)
    }

    @Test("滚动会话轮数足以撑出长列表")
    func scrollTurnCountIsLargeEnough() {
        #expect(MessageListChatGPTUITestingSupport.scrollTurnCount >= 20)
    }

    // MARK: - 夹具内容语义

    @Test("工具会话的工具名是真实工具族")
    func toolFixtureUsesRealToolFamily() {
        let names = MessageListChatGPTUITestingSupport.toolCallNames
        #expect(!names.isEmpty)
        #expect(names.contains { $0.lowercased() == "explore" || $0.lowercased() == "execute" })
    }

    @Test("工具会话至少两个同族工具以触发分组")
    func toolFixtureTriggersGrouping() {
        let names = MessageListChatGPTUITestingSupport.toolCallNames
        let groupable = names.filter {
            ["explore", "execute", "terminal"].contains($0.lowercased())
        }
        #expect(groupable.count >= 2)
    }

    @Test("reasoning 会话带推理正文")
    func reasoningFixtureHasReasoningContent() {
        let reasoning = MessageListChatGPTUITestingSupport.reasoningContent
        #expect(!reasoning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test("错误会话正文非空")
    func errorFixtureHasContent() {
        #expect(
            !MessageListChatGPTUITestingSupport.errorAssistantContent
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        )
    }
}
