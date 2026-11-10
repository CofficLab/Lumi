import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginMessageListZCode

/// V4（ZCode）UI 测试夹具契约测试。
///
/// - Important: 夹具必须
///   1. **只在** `--lumi-ui-testing` 与 `--lumi-ui-testing-message-list-zcode`
///      同时存在时生效（缺少 `--lumi-ui-testing` 时拒绝启动，
///      防止 UI 测试误连真实供应商）；
///   2. **确定性**：5 个固定会话的内容、顺序、时间戳都可预测；
///   3. **隔离**：不写用户真实数据、不触发真实付费请求；
///   4. **幂等**：重复 seed 不会产生第二份夹具。
@Suite("ZCode UI 测试夹具")
@MainActor
struct MessageListZCodeUITestingSupportTests {

    // MARK: - 启动参数

    @Test("启动参数名固定")
    func launchArgumentName() {
        #expect(MessageListZCodeUITestingSupport.launchArgument == "--lumi-ui-testing-message-list-zcode")
    }

    @Test("缺少 --lumi-ui-testing 时拒绝启用")
    func requiresGlobalUITestingArgument() {
        #expect(MessageListZCodeUITestingSupport.isEnabled(arguments: ["--lumi-ui-testing-message-list-zcode"]) == false)
    }

    @Test("缺少 V4 专用参数时拒绝启用")
    func requiresZCodeArgument() {
        #expect(MessageListZCodeUITestingSupport.isEnabled(arguments: ["--lumi-ui-testing"]) == false)
    }

    @Test("两个参数齐备时启用")
    func enabledWithBothArguments() {
        #expect(
            MessageListZCodeUITestingSupport.isEnabled(arguments: [
                "--lumi-ui-testing",
                "--lumi-ui-testing-message-list-zcode",
            ])
        )
    }

    @Test("隔离存储参数不影响启用判定")
    func isolatedStorageArgumentIsOptional() {
        #expect(
            MessageListZCodeUITestingSupport.isEnabled(arguments: [
                "--lumi-ui-testing",
                "--lumi-ui-testing-message-list-zcode",
            ])
        )
        #expect(
            MessageListZCodeUITestingSupport.isEnabled(arguments: [
                "--lumi-ui-testing",
                "--lumi-ui-testing-message-list-zcode",
                "--lumi-ui-testing-isolated-storage",
            ])
        )
    }

    // MARK: - 会话定义

    @Test("恰好 5 个固定会话")
    func exactlyFiveConversations() {
        #expect(MessageListZCodeUITestingSupport.fixtureTitles.count == 5)
    }

    @Test("会话标题互不相同")
    func titlesAreDistinct() {
        let titles = MessageListZCodeUITestingSupport.fixtureTitles
        #expect(Set(titles).count == titles.count)
    }

    @Test("会话标题非空")
    func titlesAreNonEmpty() {
        for title in MessageListZCodeUITestingSupport.fixtureTitles {
            #expect(!title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @Test("会话标题稳定不变")
    func titlesAreStable() {
        // 夹具标题是 UI 测试的定位锚点，任何改动都会让既有测试失效。
        #expect(MessageListZCodeUITestingSupport.fixtureTitles == [
            "ZCode Visual Target",
            "ZCode Long User Target",
            "ZCode Tool Target",
            "ZCode Scroll Target",
            "ZCode Streaming Target",
        ])
    }

    // MARK: - 确定性

    @Test("基准时间是固定的")
    func baseDateIsFixed() {
        #expect(MessageListZCodeUITestingSupport.baseDate == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test("长用户会话的正文长度固定")
    func longUserContentLengthIsFixed() {
        let content = MessageListZCodeUITestingSupport.longUserContent
        #expect(content.count == MessageListZCodeUITestingSupport.longUserContentLength)
        // 远超折叠阈值（120），确保进入折叠态。
        #expect(content.count > 120)
    }

    @Test("长用户会话正文包含多行")
    func longUserContentHasMultipleLines() {
        #expect(MessageListZCodeUITestingSupport.longUserContent.contains("\n"))
    }

    @Test("视觉会话正文确定")
    func visualContentIsDeterministic() {
        let first = MessageListZCodeUITestingSupport.visualUserContent
        let second = MessageListZCodeUITestingSupport.visualUserContent

        #expect(first == second)
        #expect(!first.isEmpty)
    }

    @Test("滚动会话的轮数固定")
    func scrollTurnCountIsFixed() {
        #expect(MessageListZCodeUITestingSupport.scrollTurnCount == 30)
    }

    @Test("滚动会话轮数足以撑出长列表")
    func scrollTurnCountIsLargeEnough() {
        #expect(MessageListZCodeUITestingSupport.scrollTurnCount >= 20)
    }

    // MARK: - 夹具内容语义

    @Test("工具会话的工具名是真实工具族")
    func toolFixtureUsesRealToolFamily() {
        let names = MessageListZCodeUITestingSupport.toolCallNames
        #expect(!names.isEmpty)
        // Explore / Execute 是 V4 会成组的两类工具。
        #expect(names.contains { $0.lowercased() == "explore" || $0.lowercased() == "execute" })
    }

    @Test("工具会话至少两个同族工具以触发分组")
    func toolFixtureTriggersGrouping() {
        let names = MessageListZCodeUITestingSupport.toolCallNames
        let groupable = names.filter {
            ["explore", "execute", "terminal"].contains($0.lowercased())
        }
        #expect(groupable.count >= 2)
    }

    @Test("流式会话标记为流式")
    func streamingFixtureIsMarkedStreaming() {
        #expect(MessageListZCodeUITestingSupport.isStreamingFixture)
    }
}
