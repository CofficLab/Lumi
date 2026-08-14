import Foundation
import SwiftUI
import KernelLumi
import LumiUI

struct PopoverContent: View {
    @LumiTheme private var theme
    let kernel: KernelLumi
    @Binding var isPresented: Bool

    /// 从 kernel 获取服务
    private var llmProvider: (any LLMProviderManaging)? {
        kernel.resolveService((any LLMProviderManaging).self)
    }

    /// Initial selection from LLMProviderManaging
    private var initialSelection: (providerID: String?, model: String?) {
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

            AppDivider(.vertical)

            // Right: Model List for selected provider
            ModelListView(
                kernel: kernel,
                selectedProviderID: selectedProviderID,
                initialModel: initialSelection.model,
                onSelect: { _, _ in isPresented = false }
            )
        }
        .frame(width: 780, height: 600)
        .onAppear {
            // Use initial selection if available
            if selectedProviderID == nil {
                selectedProviderID = initialSelection.providerID
                    ?? llmProvider?.allLLMProviders().first.map { $0.providerInfo.id }
            }
        }
    }
}
