import Foundation
import Testing
import KernelCore
import ProviderChatSection
import ProviderConversation

@testable import PluginConversationVerbosity

@Suite("PluginConversationVerbosity")
@MainActor
struct PluginConversationVerbosityTests {
    private func makeKernel() throws -> (KernelCoreContainer, DefaultConversationManager, DefaultChatSectionProviding) {
        let kernel = KernelCoreContainer()
        let conversations = DefaultConversationManager()
        let chat = DefaultChatSectionProviding()
        try kernel.registerProvider((any ConversationManaging).self, conversations)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        return (kernel, conversations, chat)
    }

    @Test("Verbosity 插件注册工具栏按钮并创建 Adapter + ObservationBox")
    func verbosityRegistersToolbarButton() throws {
        let (kernel, _, chat) = try makeKernel()

        let plugin = ConversationVerbosityPlugin()
        try plugin.onBoot(kernel: kernel)
        #expect(kernel.resolveProvider((any ConversationManaging).self) != nil)
        #expect(chat.barItems.count == 1)
    }

    @Test("CapabilityAdapter 收窄为 Verbosity 最小协议")
    func capabilityAdapterExposesVerbosityOnly() {
        let conversations = DefaultConversationManager()
        conversations.setGlobalVerbosity(.detailed)
        let adapter = ConversationVerbosityCapabilityAdapter(conversations: conversations)

        #expect(adapter.globalVerbosity == .detailed)
        adapter.setGlobalVerbosity(.brief)
        #expect(conversations.globalVerbosity == .brief)
    }

    @Test("Observer 直接更新 ViewModel 并支持取消")
    func observerWritesViewModelDirectlyAndSupportsCancel() throws {
        let conversations = DefaultConversationManager()
        let adapter = ConversationVerbosityCapabilityAdapter(conversations: conversations)
        let viewModel = VerbosityViewModel(capability: adapter)
        let observer = VerbosityObserver(capability: adapter, viewModel: viewModel)

        // 初值写入
        #expect(viewModel.selectedVerbosity == .defaultVerbosity)

        let revisionAfterBoot = viewModel.observationRevision
        _ = try conversations.createConversation(title: nil, projectPath: nil, providerID: nil, modelName: nil)
        #expect(viewModel.observationRevision > revisionAfterBoot)

        observer.cancel()
        let revisionAfterCancel = viewModel.observationRevision
        conversations.setGlobalVerbosity(.detailed)
        #expect(viewModel.observationRevision == revisionAfterCancel)
    }

    @Test("resolve uses conversation verbosity when a conversation is selected")
    func viewModelReadsConversationVerbosityWhenSelected() {
        let id = UUID()
        let capability = FakeVerbosityCapability(
            selectedConversationID: id,
            global: .brief,
            conversation: .detailed
        )
        let viewModel = VerbosityViewModel(capability: capability)

        #expect(viewModel.selectedVerbosity == .detailed)
    }

    @Test("resolve falls back to global verbosity when no conversation is selected")
    func viewModelReadsGlobalVerbosityWhenNoneSelected() {
        let capability = FakeVerbosityCapability(
            selectedConversationID: nil,
            global: .detailed,
            conversation: .brief
        )
        let viewModel = VerbosityViewModel(capability: capability)

        #expect(viewModel.selectedVerbosity == .detailed)
    }

    @Test("select without a conversation updates global verbosity")
    func selectWithoutConversationUpdatesGlobal() {
        let capability = FakeVerbosityCapability(
            selectedConversationID: nil,
            global: .brief,
            conversation: .brief
        )
        let viewModel = VerbosityViewModel(capability: capability)

        viewModel.select(.detailed)

        #expect(capability.globalSet == [.detailed])
        #expect(capability.awaitedSets.isEmpty)
    }

    @Test("select with a conversation updates that conversation and waits")
    @MainActor
    func selectWithConversationUpdatesConversation() async {
        let id = UUID()
        let capability = FakeVerbosityCapability(
            selectedConversationID: id,
            global: .brief,
            conversation: .brief
        )
        let viewModel = VerbosityViewModel(capability: capability)

        viewModel.select(.detailed)

        // select dispatches an async Task; yield to let it run.
        await Task.yield()
        await Task.yield()

        #expect(capability.awaitedSets.map(\.0) == [.detailed])
        #expect(capability.awaitedSets.map(\.1) == [id])
        #expect(capability.globalSet.isEmpty)
    }

    @Test("refresh re-resolves verbosity and bumps observation revision")
    func refreshBumpsRevisionAndReadsCapability() {
        let capability = FakeVerbosityCapability(
            selectedConversationID: nil,
            global: .brief,
            conversation: .brief
        )
        let viewModel = VerbosityViewModel(capability: capability)
        let before = viewModel.observationRevision

        capability.globalVerbosity = .detailed
        viewModel.refresh()

        #expect(viewModel.selectedVerbosity == .detailed)
        #expect(viewModel.observationRevision == before + 1)
    }
}

@MainActor
private final class FakeVerbosityCapability: ConversationVerbosityCapability {
    var selectedConversationID: UUID?
    var globalVerbosity: ResponseVerbosity
    var conversationVerbosity: ResponseVerbosity
    private(set) var globalSet: [ResponseVerbosity] = []
    private(set) var awaitedSets: [(ResponseVerbosity, UUID?)] = []

    init(selectedConversationID: UUID?, global: ResponseVerbosity, conversation: ResponseVerbosity) {
        self.selectedConversationID = selectedConversationID
        self.globalVerbosity = global
        self.conversationVerbosity = conversation
    }

    func verbosity(for conversationID: UUID?) -> ResponseVerbosity { conversationVerbosity }

    func setVerbosity(_ verbosity: ResponseVerbosity, for conversationID: UUID?) {}

    func setVerbosityAndWait(_ verbosity: ResponseVerbosity, for conversationID: UUID?) async {
        awaitedSets.append((verbosity, conversationID))
    }

    func setGlobalVerbosity(_ verbosity: ResponseVerbosity) {
        globalSet.append(verbosity)
    }

    func addConversationObserver(_ callback: @escaping (ConversationEvent) -> Void) -> any ConversationObserverHandle {
        NoopConversationObserverHandle()
    }
}

@MainActor
private final class NoopConversationObserverHandle: ConversationObserverHandle {
    func cancel() {}
}
