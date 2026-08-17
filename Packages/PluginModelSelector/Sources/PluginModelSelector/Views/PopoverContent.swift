import Foundation
import LumiUI
import ProviderLLMManager
import SwiftUI

/// 模型选择弹窗：左侧供应商列表 + 右侧模型列表（由旧版复刻）。
struct PopoverContent: View {
    @LumiTheme private var theme
    @ObservedObject var box: ObservableLLMProviderManagerBox
    @Binding var isPresented: Bool

    private var manager: (any LLMManaging)? { box.manager }

    /// 当前选中的供应商（初始来自内核 `LLMManaging`）。
    @State private var selectedProviderID: String?

    var body: some View {
        HStack(spacing: 0) {
            // Left: Provider List
            ProviderListView(
                box: box,
                selectedProviderID: $selectedProviderID,
                onClose: { isPresented = false }
            )
            .frame(width: 300)

            AppDivider(.vertical)

            // Right: Model List for selected provider
            ModelListView(
                box: box,
                selectedProviderID: selectedProviderID,
                initialModel: manager?.selectedModel,
                onSelect: { _, _ in isPresented = false }
            )
        }
        .frame(width: 780, height: 600)
        .onAppear {
            // Use initial selection if available
            if selectedProviderID == nil {
                selectedProviderID = manager?.selectedProviderID
                    ?? manager?.allProviders().first.map { $0.providerInfo.id }
            }
        }
    }
}
