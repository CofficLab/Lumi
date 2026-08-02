import Foundation
import SwiftUI
import LumiKernel
import LumiUI

struct PopoverContent: View {
    @LumiTheme private var theme
    let kernel: LumiKernel
    @Binding var isPresented: Bool

    /// 从 kernel 获取服务
    private var llmProvider: (any LLMProviderManaging)? {
        kernel.resolveService((any LLMProviderManaging).self)
    }

    private var conversationManaging: (any ConversationManaging)? {
        kernel.resolveService((any ConversationManaging).self)
    }

    /// Initial selection from conversation or LLMProviderManaging
    private var initialSelection: (providerID: String?, model: String?) {
        if let conversations = conversationManaging,
           let convID = conversations.selectedConversationID,
           let convProviderID = conversations.providerID(for: convID) {
            let convModel = conversations.modelName(for: convID)
            return (convProviderID, convModel)
        }
        return (llmProvider?.selectedProviderID, llmProvider?.selectedModel)
    }

    @State private var selectedProviderID: String?
    @State private var searchText = ""

    var body: some View {
        HStack(spacing: 0) {
            // Left: Provider List
            ProviderListView(
                kernel: kernel,
                selectedProviderID: $selectedProviderID,
                onClose: { isPresented = false }
            )
            .frame(width: 300)

            Divider()

            // Right: Model List for selected provider
            ModelListView(
                kernel: kernel,
                selectedProviderID: selectedProviderID,
                initialModel: initialSelection.model,
                onSelect: { _, _ in isPresented = false }
            )
        }
        .frame(width: 600, height: 600)
        .onAppear {
            // Use initial selection if available
            if selectedProviderID == nil {
                selectedProviderID = initialSelection.providerID
                    ?? llmProvider?.allLLMProviders().first.map { type(of: $0).info.id }
            }
        }
    }
}
