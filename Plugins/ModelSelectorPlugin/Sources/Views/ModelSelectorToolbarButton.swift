import SwiftUI
import LumiCoreKit
import LumiUI

/// 模型选择器工具栏按钮
///
/// 显示当前供应商 + 模型名称，点击弹出 ModelSelectorView 的 Popover。
public struct ModelSelectorToolbarButton: View {
    @EnvironmentObject private var llmVM: AppLLMVM
    @EnvironmentObject private var conversationVM: WindowConversationVM

    public var body: some View {
        sidebarToolbarPopover(
            detailView: ModelSelectorView(),
            id: "model-selector"
        ) {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.system(size: 13))
                Text(currentModelDisplayText)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "chevron.up")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .accessibilityLabel(String(localized: "Select Model", bundle: .module))
        .accessibilityHint(String(localized: "Select Model Hint", bundle: .module))
    }

    /// 当前显示的「供应商 + 模型」文案
    private var currentModelDisplayText: String {
        let preference = conversationVM.getModelPreference()
        let providerId = preference?.providerId ?? llmVM.selectedProviderId
        let model = preference?.model ?? llmVM.currentModel
        guard !model.isEmpty else {
            if llmVM.isAutoMode {
                return "Auto"
            }
            return String(localized: "No Model Selected", bundle: .module)
        }

        let displayModel: String
        if let localProvider = llmVM.createProvider(id: providerId) as? any SuperLocalLLMProvider,
           let name = localProvider.displayName(forModelId: model) {
            displayModel = name
        } else {
            displayModel = model
        }

        if llmVM.isAutoMode {
            return "Auto · \(displayModel)"
        }

        guard let providerType = llmVM.providerType(forId: providerId) else {
            return displayModel
        }
        return "\(providerType.shortName) · \(displayModel)"
    }
}
