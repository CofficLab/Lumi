import Foundation
import SwiftUI
import LumiKernel
import LumiUI

/// 模型列表视图
///
/// 显示指定供应商的模型列表，支持搜索和选择。
/// 从 kernel 自动获取 LLMProviderManaging 和 ConversationManaging 服务。
struct ModelListView: View {
    @LumiTheme private var theme
    let kernel: LumiKernel
    let selectedProviderID: String?
    let initialModel: String?
    var onSelect: ((_ providerID: String, _ model: String) -> Void)? = nil

    @State private var searchText = ""

    /// 从 kernel 获取服务
    private var llmProvider: (any LLMProviderManaging)? {
        kernel.resolveService((any LLMProviderManaging).self)
    }

    private var conversationManaging: (any ConversationManaging)? {
        kernel.resolveService((any ConversationManaging).self)
    }

    /// 当前选中供应商的显示名称
    private var selectedProviderDisplayName: String? {
        guard let providerID = selectedProviderID,
              let provider = llmProvider?.allLLMProviders().first(where: { type(of: $0).info.id == providerID })
        else {
            return nil
        }
        return type(of: provider).info.displayName
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(selectedProviderDisplayName ?? "Models")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(theme.surface)

            Divider()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(theme.textTertiary)
                TextField("Search models", text: $searchText)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(theme.surface.opacity(0.5))

            Divider()

            // Model items
            if let providerID = selectedProviderID, let llmProvider {
                let models = llmProvider.models(for: providerID)
                let filteredModels = searchText.isEmpty ? models : models.filter {
                    $0.localizedCaseInsensitiveContains(searchText)
                }

                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredModels, id: \.self) { model in
                            let info = llmProvider.allLLMProviders()
                                .first { type(of: $0).info.id == providerID }.map { type(of: $0).info }
                            let displayName = info?.modelDisplayNames[model] ?? model
                            let isSelected = model == initialModel

                            ModelListItem(
                                displayName: displayName,
                                model: model,
                                isSelected: isSelected,
                                onSelect: {
                                    onSelect?(providerID, model)
                                    llmProvider.selectModel(providerID: providerID, model: model)
                                    if let conversations = conversationManaging,
                                       let convID = conversations.selectedConversationID {
                                        conversations.selectProvider(id: providerID, model: model, for: convID)
                                    }
                                }
                            )
                        }
                    }
                    .padding(8)
                }
            } else {
                Spacer()
                Text("Select a provider")
                    .font(.system(size: 13))
                    .foregroundColor(theme.textTertiary)
                Spacer()
            }
        }
        .background(theme.background)
    }
}
