import Foundation
import ProviderConversationInputBlock
import Testing
@testable import PluginConversationInput

/// 回归 #518：「Send to Conversation」递交的折叠块暂存在输入插件的待插入队列里，
/// 由**当前挂载的编辑器**消费。旧实现不记录块的归属对话，切换会话也不清空队列：
/// A 的选区还没被消费就切到 B，B 的输入框更新时会把 A 的代码插进去，跨对话泄漏。
///
/// 修复后块严格绑定递交时选中的对话：
/// - `pendingBlock` 只在归属对话仍被选中时暴露（实时判定，切换通知与落定清空
///   之间的窗口也安全）；
/// - 选中态真正落定到别的对话时，归属旧对话的未消费块随草稿一起丢弃，
///   切回原对话也不复活；
/// - 瞬时选中往返（#781 的 `create_new_conversation` 链路）不清空块。
@Suite("折叠块跨对话隔离（#518）")
@MainActor
struct PendingBlockConversationBindingTests {

    /// 装配：能力层 + ViewModel + 生产同款选中会话观察者。
    private func makeFixture(
        selected: UUID?
    ) -> (capability: SendActionBarTestCapability, viewModel: ConversationInputViewModel, observer: ActionBarConversationObserver) {
        let capability = SendActionBarTestCapability()
        capability.selectedConversationID = selected
        let viewModel = ConversationInputViewModel(capability: capability)
        let observer = ActionBarConversationObserver(capability: capability, viewModel: viewModel)
        return (capability, viewModel, observer)
    }

    private func makeBlock(text: String = "let secret = 42", title: String = "main.swift") -> ConversationInputBlock {
        ConversationInputBlock(
            text: text,
            title: title,
            systemImage: "chevron.left.forwardslash.chevron.right",
            collapseThreshold: 400
        )
    }

    @Test("切走后未消费的块立即不再暴露，落定后也不暴露")
    func unconsumedBlockIsHiddenImmediatelyAfterSwitch() async throws {
        let a = UUID()
        let b = UUID()
        let (capability, viewModel, observer) = makeFixture(selected: a)
        defer { observer.cancel() }

        let block = makeBlock()
        viewModel.enqueue(block)
        #expect(viewModel.pendingBlock?.id == block.id)

        capability.emitSelectedConversation(b)
        // 关键断言：不等落定清空，暴露判定读实时选中态——切换通知发出的同一
        // 主 actor 连续段里，B 的编辑器就已经拿不到 A 的块。
        #expect(viewModel.pendingBlock == nil)

        await awaitSettle()
        #expect(viewModel.pendingBlock == nil)
    }

    @Test("落定切换丢弃块，切回原对话也不复活")
    func settledSwitchDiscardsBlockEvenAfterReturning() async throws {
        let a = UUID()
        let b = UUID()
        let (capability, viewModel, observer) = makeFixture(selected: a)
        defer { observer.cancel() }

        viewModel.enqueue(makeBlock())
        capability.emitSelectedConversation(b)
        await awaitSettle()
        #expect(viewModel.pendingBlock == nil)

        // 切回 A：块已随旧草稿丢弃，不能复活插进 A 的新草稿。
        capability.emitSelectedConversation(a)
        await awaitSettle()
        #expect(viewModel.pendingBlock == nil)
    }

    @Test("归属对话内块可正常消费，FIFO 依次推进")
    func blockStaysConsumableInOriginatingConversation() async throws {
        let a = UUID()
        let (capability, viewModel, observer) = makeFixture(selected: a)
        defer { observer.cancel() }

        let first = makeBlock(text: "first", title: "First.swift")
        let second = makeBlock(text: "second", title: "Second.swift")
        viewModel.enqueue(first)
        viewModel.enqueue(second)

        #expect(viewModel.pendingBlock?.id == first.id)
        viewModel.consumePendingBlock(id: first.id)
        #expect(viewModel.pendingBlock?.id == second.id)
        viewModel.consumePendingBlock(id: second.id)
        #expect(viewModel.pendingBlock == nil)
    }

    @Test("瞬时选中往返 A→B→A 保留未消费的块")
    func transientRoundTripKeepsPendingBlock() async throws {
        let a = UUID()
        let b = UUID()
        let (capability, viewModel, observer) = makeFixture(selected: a)
        defer { observer.cancel() }

        let block = makeBlock()
        viewModel.enqueue(block)

        // 复刻 create_new_conversation 链路：两次通知在同一连续段内发出。
        capability.emitSelectedConversation(b)
        capability.emitSelectedConversation(a)
        await awaitSettle()

        #expect(viewModel.pendingBlock?.id == block.id)
    }

    @Test("切换窗口内为新对话递交的块不被落定清空误删")
    func blockEnqueuedDuringSwitchWindowForNewConversationSurvives() async throws {
        let a = UUID()
        let b = UUID()
        let (capability, viewModel, observer) = makeFixture(selected: a)
        defer { observer.cancel() }

        let stale = makeBlock(text: "stale A selection", title: "A.swift")
        viewModel.enqueue(stale)

        capability.emitSelectedConversation(b)
        // 落定判定尚未执行，用户已在新对话里递交了新的块。
        let fresh = makeBlock(text: "fresh B selection", title: "B.swift")
        viewModel.enqueue(fresh)

        await awaitSettle()
        // A 的块被丢弃，B 的块保留且可消费。
        #expect(viewModel.pendingBlock?.id == fresh.id)
        viewModel.consumePendingBlock(id: fresh.id)
        #expect(viewModel.pendingBlock == nil)
    }
}