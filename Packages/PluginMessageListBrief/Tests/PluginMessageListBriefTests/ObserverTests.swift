import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderConversationState
import ProviderDeveloperMode
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageStreaming
import SwiftUI
import Testing
@testable import PluginMessageListBrief

/// `Observers/` 五个订阅器的单元测试。
///
/// 覆盖「Provider 事件 → ViewModel 状态」这条转发链路：
/// - 构造时同步一次初始状态
/// - 事件到达时按选中会话过滤后再写入
/// - `cancel()` 确实解除订阅且可重复调用
@MainActor
struct ObserverTests {

    private let conversationID = UUID()
    private let otherConversationID = UUID()

    private func makeMessage(
        conversationID: UUID,
        role: MessageRole,
        content: String = "hi",
        createdAt: Date = Date()
    ) -> Message {
        Message(
            id: UUID(),
            conversationID: conversationID,
            role: role,
            content: content,
            createdAt: createdAt
        )
    }

    // MARK: - MessageObserver

    /// 构造带选中会话的 services。
    ///
    /// `ConversationMessageListVM.activate` 会先校验 `selectedConversationID`
    /// 与入参一致（防旧会话的延迟回调），因此 `conversations` 不能传 nil，
    /// 否则 VM 永远处于未选中态，所有断言都会落空。
    private func makeServices(
        conversationID: UUID,
        messages: ProviderTestDoubles.StubMessageManager
    ) -> MessageListServices {
        MessageListServices(
            conversations: MessageListConversationCapabilityAdapter(
                conversations: ProviderTestDoubles.StubConversationManager(selected: conversationID)
            ),
            developerMode: nil,
            messages: MessageListMessageCapabilityAdapter(messages: messages),
            rendering: nil,
            agentTurn: nil
        )
    }

    @Test("MessageObserver 把消息变化转发给 VM")
    func messageObserverForwardsChanges() async {
        let messages = ProviderTestDoubles.StubMessageManager()
        let vm = ConversationMessageListVM(
            services: makeServices(conversationID: conversationID, messages: messages)
        )
        await vm.activate(conversationID: conversationID)

        let observer = MessageObserver(messages: messages, vm: vm)
        defer { observer.cancel() }

        // 插入一条当前会话的用户消息，VM 应立即反映到可见行里。
        let message = makeMessage(conversationID: conversationID, role: .user)
        messages.emit(.inserted(message, conversationID: conversationID))

        #expect(vm.rows.contains { row in
            if case let .agentTurn(item) = row {
                return item.pendingAnchorMessageID == message.id
            }
            return false
        }, "插入的 user 消息应出现在某个 turn 的 userMessages 中")
    }

    @Test("MessageObserver 对其他会话的变更不响应")
    func messageObserverIgnoresOtherConversations() async {
        let messages = ProviderTestDoubles.StubMessageManager()
        let vm = ConversationMessageListVM(
            services: makeServices(conversationID: conversationID, messages: messages)
        )
        await vm.activate(conversationID: conversationID)
        let before = vm.rows

        let observer = MessageObserver(messages: messages, vm: vm)
        defer { observer.cancel() }

        let message = makeMessage(conversationID: otherConversationID, role: .user)
        messages.emit(.inserted(message, conversationID: otherConversationID))

        #expect(vm.rows == before, "非活动会话的消息不应进入当前列表")
    }

    @Test("MessageObserver cancel 后不再收到事件")
    func messageObserverCancelStopsDelivery() async {
        let messages = ProviderTestDoubles.StubMessageManager()
        let services = MessageListServices(
            conversations: nil,
            developerMode: nil,
            messages: MessageListMessageCapabilityAdapter(messages: messages),
            rendering: nil,
            agentTurn: nil
        )
        let vm = ConversationMessageListVM(services: services)
        await vm.activate(conversationID: conversationID)

        let observer = MessageObserver(messages: messages, vm: vm)
        observer.cancel()
        observer.cancel() // 重复取消必须无副作用

        #expect(messages.handle.cancelCount == 1, "重复 cancel 只会真正取消一次")

        let before = vm.rows
        let message = makeMessage(conversationID: conversationID, role: .user)
        messages.emit(.inserted(message, conversationID: conversationID))
        #expect(vm.rows == before)
    }

    // MARK: - DeveloperModeObserver

    @Test("DeveloperModeObserver 构造时同步初始状态并订阅变化")
    func developerModeObserverSyncsAndFollows() {
        let provider = ProviderTestDoubles.StubDeveloperModeProvider(enabled: true)
        let services = MessageListServices(
            conversations: nil,
            developerMode: MessageListDeveloperModeCapabilityAdapter(developerMode: provider),
            messages: nil,
            rendering: nil,
            agentTurn: nil
        )
        let vm = ConversationMessageListVM(services: services)

        let observer = DeveloperModeObserver(
            developerMode: MessageListDeveloperModeCapabilityAdapter(developerMode: provider),
            vm: vm
        )
        #expect(vm.isDeveloperModeEnabled, "构造时应同步 provider 当前值")

        provider.setEnabled(false)
        #expect(vm.isDeveloperModeEnabled == false)

        observer.cancel()
        provider.setEnabled(true)
        #expect(vm.isDeveloperModeEnabled == false, "cancel 后不应再收到事件")
        #expect(provider.handle.cancelCount == 1)
    }

    // MARK: - SelectedConversationObserver

    @Test("SelectedConversationObserver 无 ConversationStateObserver 时直接同步 stateVM")
    func selectedConversationObserverWithoutStateObserver() async {
        let conversations = ProviderTestDoubles.StubConversationManager(selected: conversationID)
        let messages = ProviderTestDoubles.StubMessageManager()
        let services = MessageListServices(
            conversations: MessageListConversationCapabilityAdapter(conversations: conversations),
            developerMode: nil,
            messages: MessageListMessageCapabilityAdapter(messages: messages),
            rendering: nil,
            agentTurn: nil
        )
        let vm = ConversationMessageListVM(services: services)
        let stateVM = ConversationStateVM()

        let observer = SelectedConversationObserver(
            conversations: conversations,
            vm: vm,
            stateVM: stateVM,
            conversationStateObserver: nil
        )

        #expect(stateVM.selectedConversationID == conversationID, "构造时应同步当前选中会话")

        conversations.emitSelection(otherConversationID)
        // 交给 activate 的 Task 跑完。
        await Task.yield()
        #expect(stateVM.selectedConversationID == otherConversationID)

        observer.cancel()
        #expect(conversations.selectedHandle.cancelCount == 1)
    }

    @Test("SelectedConversationObserver 优先走 ConversationStateObserver 转发")
    func selectedConversationObserverPrefersStateObserver() {
        let conversations = ProviderTestDoubles.StubConversationManager(selected: conversationID)
        let stateProvider = ProviderTestDoubles.StubConversationStateProvider()
        let streaming = ProviderTestDoubles.StubStreamingProvider()
        let services = MessageListServices(
            conversations: MessageListConversationCapabilityAdapter(conversations: conversations),
            developerMode: nil,
            messages: nil,
            rendering: nil,
            agentTurn: nil
        )
        let vm = ConversationMessageListVM(services: services)
        let stateVM = ConversationStateVM()
        let stateObserver = ConversationStateObserver(
            state: stateProvider,
            streaming: streaming,
            conversationID: conversations.selectedConversationID,
            stateVM: stateVM
        )

        let observer = SelectedConversationObserver(
            conversations: conversations,
            vm: vm,
            stateVM: stateVM,
            conversationStateObserver: stateObserver
        )
        defer {
            observer.cancel()
            stateObserver.cancel()
        }

        #expect(stateVM.selectedConversationID == conversationID)
        // 切换会话时 stateObserver 自身重置并重新发布，stateVM 应跟随。
        conversations.emitSelection(otherConversationID)
        #expect(stateVM.selectedConversationID == otherConversationID)
    }

    // MARK: - ConversationStateObserver

    @Test("ConversationStateObserver 构造时发布当前会话的活动投影")
    func conversationStateObserverPublishesInitialProjection() {
        let stateProvider = ProviderTestDoubles.StubConversationStateProvider(
            snapshots: [
                conversationID: ConversationStateSnapshot(
                    conversationID: conversationID,
                    agentLoopState: .running,
                    activity: .thinking
                )
            ]
        )
        let streaming = ProviderTestDoubles.StubStreamingProvider()
        let stateVM = ConversationStateVM()
        let observer = ConversationStateObserver(
            state: stateProvider,
            streaming: streaming,
            conversationID: conversationID,
            stateVM: stateVM
        )
        defer { observer.cancel() }

        #expect(stateVM.activity?.phase == .thinking, "构造时应立即发布一次 activity")
    }

    @Test("ConversationStateObserver 处理会话状态 updated 事件")
    func conversationStateObserverHandlesUpdated() {
        let stateProvider = ProviderTestDoubles.StubConversationStateProvider()
        let stateVM = ConversationStateVM()
        let observer = ConversationStateObserver(
            state: stateProvider,
            streaming: nil,
            conversationID: conversationID,
            stateVM: stateVM
        )
        defer { observer.cancel() }

        #expect(stateVM.activity == nil)

        stateProvider.snapshots[conversationID] = ConversationStateSnapshot(
            conversationID: conversationID,
            agentLoopState: .running,
            activity: .executingTool
        )
        stateProvider.emit(.updated(conversationID))

        #expect(stateVM.activity?.phase == .executingTool)
    }

    @Test("ConversationStateObserver 处理会话状态 removed 事件回到 nil")
    func conversationStateObserverHandlesRemoved() {
        let stateProvider = ProviderTestDoubles.StubConversationStateProvider(
            snapshots: [
                conversationID: ConversationStateSnapshot(
                    conversationID: conversationID,
                    agentLoopState: .running,
                    activity: .thinking
                )
            ]
        )
        let stateVM = ConversationStateVM()
        let observer = ConversationStateObserver(
            state: stateProvider,
            streaming: nil,
            conversationID: conversationID,
            stateVM: stateVM
        )
        defer { observer.cancel() }

        #expect(stateVM.activity != nil)
        stateProvider.emit(.removed(conversationID))
        #expect(stateVM.activity == nil, "会话被移除后活动投影应清空")
    }

    @Test("ConversationStateObserver 忽略非选中会话的状态事件")
    func conversationStateObserverIgnoresOtherConversations() {
        let stateProvider = ProviderTestDoubles.StubConversationStateProvider(
            snapshots: [
                conversationID: ConversationStateSnapshot(
                    conversationID: conversationID,
                    agentLoopState: .running,
                    activity: .thinking
                )
            ]
        )
        let stateVM = ConversationStateVM()
        let observer = ConversationStateObserver(
            state: stateProvider,
            streaming: nil,
            conversationID: conversationID,
            stateVM: stateVM
        )
        defer { observer.cancel() }

        stateProvider.snapshots[otherConversationID] = ConversationStateSnapshot(
            conversationID: otherConversationID,
            agentLoopState: .running,
            activity: .executingTool
        )
        stateProvider.emit(.updated(otherConversationID))

        #expect(stateVM.activity?.phase == .thinking, "其他会话的事件不应改变当前投影")
    }

    @Test("ConversationStateObserver 流式阶段变化会刷新投影")
    func conversationStateObserverFollowsStreamingStage() {
        let stateProvider = ProviderTestDoubles.StubConversationStateProvider(
            snapshots: [
                conversationID: ConversationStateSnapshot(
                    conversationID: conversationID,
                    agentLoopState: .running,
                    activity: .sending
                )
            ]
        )
        let streaming = ProviderTestDoubles.StubStreamingProvider()
        streaming.stages[conversationID] = .thinking
        let stateVM = ConversationStateVM()
        let observer = ConversationStateObserver(
            state: stateProvider,
            streaming: streaming,
            conversationID: conversationID,
            stateVM: stateVM
        )
        defer { observer.cancel() }

        #expect(stateVM.activity?.phase == .thinking, "streaming 阶段应优先决定投影")

        streaming.emitStage(.generating, for: conversationID)
        #expect(stateVM.activity?.phase == .generating)
    }

    @Test("ConversationStateObserver updateSelectedConversation 切换时清空并重取状态")
    func conversationStateObserverResetsOnSwitch() {
        let stateProvider = ProviderTestDoubles.StubConversationStateProvider(
            snapshots: [
                conversationID: ConversationStateSnapshot(
                    conversationID: conversationID,
                    agentLoopState: .running,
                    activity: .thinking
                ),
                otherConversationID: ConversationStateSnapshot(
                    conversationID: otherConversationID,
                    agentLoopState: .running,
                    activity: .executingTool
                )
            ]
        )
        let stateVM = ConversationStateVM()
        let observer = ConversationStateObserver(
            state: stateProvider,
            streaming: nil,
            conversationID: conversationID,
            stateVM: stateVM
        )
        defer { observer.cancel() }

        #expect(stateVM.activity?.phase == .thinking)

        observer.updateSelectedConversation(otherConversationID)
        #expect(stateVM.activity?.phase == .executingTool, "切换后应按新会话重新发布")

        observer.updateSelectedConversation(nil)
        #expect(stateVM.activity == nil, "切到 nil 应清空")
    }

    @Test("ConversationStateObserver 重复传入同一会话不重复发布")
    func conversationStateObserverSkipsRedundantSwitch() {
        let stateProvider = ProviderTestDoubles.StubConversationStateProvider(
            snapshots: [
                conversationID: ConversationStateSnapshot(
                    conversationID: conversationID,
                    agentLoopState: .running,
                    activity: .thinking
                )
            ]
        )
        let stateVM = ConversationStateVM()
        let observer = ConversationStateObserver(
            state: stateProvider,
            streaming: nil,
            conversationID: conversationID,
            stateVM: stateVM
        )
        defer { observer.cancel() }

        // 先清空状态源，再重复传同一 id：若实现不早退，会读到空快照并清空投影。
        stateProvider.snapshots.removeValue(forKey: conversationID)
        observer.updateSelectedConversation(conversationID)

        #expect(stateVM.activity?.phase == .thinking, "同一会话重复更新应被 guard 挡下")
    }

    @Test("ConversationStateObserver cancel 后不再收到事件")
    func conversationStateObserverCancelStopsDelivery() {
        let stateProvider = ProviderTestDoubles.StubConversationStateProvider()
        let stateVM = ConversationStateVM()
        let observer = ConversationStateObserver(
            state: stateProvider,
            streaming: nil,
            conversationID: conversationID,
            stateVM: stateVM
        )
        observer.cancel()
        observer.cancel()

        stateProvider.snapshots[conversationID] = ConversationStateSnapshot(
            conversationID: conversationID,
            agentLoopState: .running,
            activity: .thinking
        )
        stateProvider.emit(.updated(conversationID))

        #expect(stateVM.activity == nil)
    }

    // MARK: - VerbosityObservationBox

    @Test("VerbosityObservationBox 构造时注册 item，cancel 时移除")
    func verbosityBoxRegistersAndUnregisters() {
        let chat = ProviderTestDoubles.StubChatSectionProvider()
        let box = VerbosityObservationBox(
            conversations: nil,
            chat: chat,
            pluginID: "test.plugin",
            expectedVerbosity: .brief,
            makeView: { AnyView(EmptyView()) }
        )

        #expect(chat.addedItems.count == 1)
        #expect(chat.addedItems.first?.id == "test.plugin")
        #expect(chat.hasItem(id: "test.plugin"))

        box.cancel()
        #expect(chat.removedItemIDs == ["test.plugin"])
        #expect(!chat.hasItem(id: "test.plugin"))

        box.cancel() // 重复取消不再 remove
        #expect(chat.removedItemIDs.count == 1)
    }

    @Test("VerbosityObservationBox 在 verbosity 变化时请求刷新 item")
    func verbosityBoxRefreshesOnVerbosityChange() {
        let conversations = ProviderTestDoubles.StubConversationManager(
            selected: conversationID,
            verbosity: .brief
        )
        let chat = ProviderTestDoubles.StubChatSectionProvider()
        let box = VerbosityObservationBox(
            conversations: conversations,
            chat: chat,
            pluginID: "test.plugin",
            expectedVerbosity: .brief,
            makeView: { AnyView(EmptyView()) }
        )
        defer { box.cancel() }

        #expect(chat.refreshCount == 0)

        conversations.emit(.verbosityChanged(conversationID))
        #expect(chat.refreshCount == 1)

        conversations.emit(.selected(conversationID))
        #expect(chat.refreshCount == 2)

        // 其它语义事件不应触发刷新。
        conversations.emit(.listChanged)
        conversations.emit(.updated(conversationID))
        #expect(chat.refreshCount == 2, "非 verbosity/selected 事件不应刷新")
    }

    @Test("VerbosityObservationBox 的 isActive 跟随选中会话的详细程度")
    func verbosityBoxIsActiveFollowsVerbosity() {
        let conversations = ProviderTestDoubles.StubConversationManager(
            selected: conversationID,
            verbosity: .brief
        )
        let chat = ProviderTestDoubles.StubChatSectionProvider()
        let box = VerbosityObservationBox(
            conversations: conversations,
            chat: chat,
            pluginID: "test.plugin",
            expectedVerbosity: .brief,
            makeView: { AnyView(EmptyView()) }
        )
        defer { box.cancel() }

        let item = try! #require(chat.addedItems.first)

        #expect(item.isActive())
        conversations.emitSelection(nil)
        #expect(item.isActive() == false, "无选中会话时不参与渲染")
        conversations.emitSelection(otherConversationID)
        #expect(item.isActive(), "选中会话的详细度仍为 brief")
        conversations.setVerbosity(.detailed, for: otherConversationID)
        #expect(item.isActive() == false, "详细度不再匹配时不参与渲染")
    }

    @Test("VerbosityObservationBox cancel 后不再刷新")
    func verbosityBoxCancelStopsRefresh() {
        let conversations = ProviderTestDoubles.StubConversationManager(selected: conversationID)
        let chat = ProviderTestDoubles.StubChatSectionProvider()
        let box = VerbosityObservationBox(
            conversations: conversations,
            chat: chat,
            pluginID: "test.plugin",
            expectedVerbosity: .brief,
            makeView: { AnyView(EmptyView()) }
        )
        box.cancel()

        conversations.emit(.verbosityChanged(conversationID))
        #expect(chat.refreshCount == 0)
        #expect(conversations.conversationHandle.cancelCount == 1)
    }
}
