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
}
