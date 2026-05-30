import AgentToolKit
import LLMKit
import LumiCoreKit
import PluginAgentMessageRenderer
import SwiftUI

extension PluginAgentMessageRenderer.AssistantMessageRenderer: SuperMessageRenderer {}
extension PluginAgentMessageRenderer.DefaultMarkdownRenderer: SuperMessageRenderer {}
extension PluginAgentMessageRenderer.ErrorMessageRenderer: SuperMessageRenderer {}
extension PluginAgentMessageRenderer.LoadingLocalModelRenderer: SuperMessageRenderer {}
extension PluginAgentMessageRenderer.StatusMessageRenderer: SuperMessageRenderer {}
extension PluginAgentMessageRenderer.SystemMessageRenderer: SuperMessageRenderer {}
extension PluginAgentMessageRenderer.ToolOutputRenderer: SuperMessageRenderer {}
extension PluginAgentMessageRenderer.TurnCompletedRenderer: SuperMessageRenderer {}
extension PluginAgentMessageRenderer.UserMessageRenderer: SuperMessageRenderer {}

actor AgentMessageRendererPlugin: SuperPlugin {
    static let shared = AgentMessageRendererPlugin()
    static let id = PluginAgentMessageRenderer.MessageRendererPlugin.id
    static let displayName = PluginAgentMessageRenderer.MessageRendererPlugin.displayName
    static let description = PluginAgentMessageRenderer.MessageRendererPlugin.description
    static let iconName = PluginAgentMessageRenderer.MessageRendererPlugin.iconName
    static var category: PluginCategory { PluginCategory(package: PluginAgentMessageRenderer.MessageRendererPlugin.category) }
    static var order: Int { PluginAgentMessageRenderer.MessageRendererPlugin.order }

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(MessageRendererRuntimeBridge(content: content()))
    }

    @MainActor
    func messageRenderers() -> [any SuperMessageRenderer] {
        [
            PluginAgentMessageRenderer.TurnCompletedRenderer(),
            PluginAgentMessageRenderer.LoadingLocalModelRenderer(),
            PluginAgentMessageRenderer.ToolOutputRenderer(),
            PluginAgentMessageRenderer.UserMessageRenderer(),
            PluginAgentMessageRenderer.AssistantMessageRenderer(),
            PluginAgentMessageRenderer.SystemMessageRenderer(),
            PluginAgentMessageRenderer.StatusMessageRenderer(),
            PluginAgentMessageRenderer.ErrorMessageRenderer(),
            PluginAgentMessageRenderer.DefaultMarkdownRenderer(),
        ]
    }
}

@MainActor
private struct MessageRendererRuntimeBridge<Content: View>: View {
    let content: Content

    @EnvironmentObject private var projectVM: WindowProjectVM
    @EnvironmentObject private var inputQueueVM: WindowInputQueueVM
    @EnvironmentObject private var taskCancellationVM: WindowTaskCancellationVM
    @EnvironmentObject private var llmVM: AppLLMVM
    @EnvironmentObject private var providerRegistry: LLMProviderRegistry

    var body: some View {
        content
            .onAppear(perform: sync)
            .onChange(of: projectVM.languagePreference) { _, _ in sync() }
            .onChange(of: llmVM.verbosity) { _, _ in sync() }
            .onChange(of: llmVM.selectedProviderId) { _, _ in sync() }
    }

    private func sync() {
        MessageRendererRuntime.languagePreferenceProvider = { projectVM.languagePreference }
        MessageRendererRuntime.showsAssistantHeaderProvider = { llmVM.verbosity == .detailed }
        MessageRendererRuntime.enqueueText = { text in inputQueueVM.enqueueText(text) }
        MessageRendererRuntime.cancelTurn = { conversationId in
            taskCancellationVM.requestCancel(conversationId: conversationId)
        }
        MessageRendererRuntime.selectedProviderIdProvider = { llmVM.selectedProviderId }
        MessageRendererRuntime.apiKeyProvider = { providerId in llmVM.getApiKey(for: providerId) }
        MessageRendererRuntime.apiKeySetter = { providerId, apiKey in
            llmVM.setApiKey(apiKey, for: providerId)
        }
        MessageRendererRuntime.providerInfoProvider = { providerId in
            providerRegistry.allProviders().first(where: { $0.id == providerId })
        }
        MessageRendererRuntime.localModelInfoProvider = { providerId, modelId in
            guard let provider = providerRegistry.createProvider(id: providerId) as? any SuperLocalLLMProvider else {
                return nil
            }
            let models = await provider.getAvailableModels()
            return models.first(where: { $0.id == modelId })
        }
    }
}
