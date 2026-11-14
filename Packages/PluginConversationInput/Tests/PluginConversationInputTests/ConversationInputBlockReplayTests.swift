import Foundation
import ProviderConversation
import ProviderConversationInput
import ProviderConversationInputBlock
import ProviderConversationState
import ProviderMessage
import ProviderMessageSender
import Testing
@testable import PluginConversationInput

/// 启动补投多个折叠块时的 FIFO 保真（回归 #204）。
///
/// `DefaultConversationInputBlockProvider` 在第一个观察者注册前缓冲提交的块，
/// 注册时**同步**逐个补投。输入插件可能晚于一次右键发送才装配好，于是
/// `ConversationInputObserver` 一注册就会连续触发多次 `enqueue`。
///
/// 旧实现用单槽 `pendingBlock`，后一个块直接覆盖前一个——补投 A、B 后只剩 B，
/// A 静默丢失。本套件走**真实生产链路**（真实 Provider + Adapter + Observer），
/// 锁住「补投的块按提交顺序逐个待插入，消费一个推进到下一个」。
@MainActor
@Suite("ConversationInput 折叠块启动补投 FIFO")
struct ConversationInputBlockReplayTests {

    @Test("启动补投的多个块按顺序逐个待插入，消费一个推进到下一个")
    func startupReplayDeliversBlocksInOrder() {
        let provider = DefaultConversationInputBlockProvider()
        let first = ConversationInputBlock(text: "let a = 1", title: "a.swift")
        let second = ConversationInputBlock(text: "let b = 2", title: "b.swift")
        let third = ConversationInputBlock(text: "let c = 3", title: "c.swift")

        // 观察者注册前提交：全部进缓冲区，模拟输入插件晚于生产方装配。
        provider.submit(first)
        provider.submit(second)
        provider.submit(third)

        let capability = ConversationInputCapabilityAdapter(
            input: nil,
            blocks: provider,
            sender: nil,
            conversations: nil,
            conversationState: nil
        )
        let viewModel = ConversationInputViewModel(capability: capability)
        // Observer 注册块观察者 → Provider 同步补投 first/second/third → enqueue ×3。
        let observer = ConversationInputObserver(capability: capability, viewModel: viewModel)

        // 单槽覆盖会让队首变成 third；FIFO 必须保留 first。
        #expect(viewModel.pendingBlock?.id == first.id)

        // 编辑器消费队首后推进到下一个（onBlockInserted 的真实回调）。
        viewModel.consumePendingBlock(id: first.id)
        #expect(viewModel.pendingBlock?.id == second.id)

        viewModel.consumePendingBlock(id: second.id)
        #expect(viewModel.pendingBlock?.id == third.id)

        viewModel.consumePendingBlock(id: third.id)
        #expect(viewModel.pendingBlock == nil)

        observer.cancel()
    }
}