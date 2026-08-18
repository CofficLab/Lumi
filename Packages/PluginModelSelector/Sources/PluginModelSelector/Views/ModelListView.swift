import Foundation
import LumiUI
import ProviderLLMManager
import KitLLM
import SwiftUI

/// 模型列表视图（由旧版 ModelSelectorPlugin 复刻）。
///
/// 显示指定供应商的模型列表，支持搜索和选择。
/// 数据源为内核 `LLMManaging`（经 `ObservableLLMProviderManagerBox` 订阅）。
struct ModelListView: View {
    @LumiTheme private var theme
    @ObservedObject var box: ObservableLLMProviderManagerBox
    let selectedProviderID: String?
    let initialModel: String?
    var onSelect: ((_ providerID: String, _ model: String) -> Void)? = nil

    @State private var searchText = ""

    private var manager: (any LLMManaging)? { box.manager }

    /// 当前选中供应商的显示名称
    private var selectedProviderDisplayName: String? {
        guard let providerID = selectedProviderID,
              let provider = manager?.provider(id: providerID)
        else {
            return nil
        }
        return provider.providerInfo.displayName
    }

    /// 当前选中供应商的模型元数据字典（id → LLMModelInfo）
    private var selectedProviderModelInfos: [String: LLMModelInfo] {
        guard let providerID = selectedProviderID,
              let provider = manager?.provider(id: providerID)
        else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: provider.providerInfo.models.map { ($0.id, $0) })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(selectedProviderDisplayName ?? "Models")
                    .font(.appCallout)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(theme.surface)

            AppDivider()

            // Search
            AppSearchBar(text: $searchText, placeholder: "Search models")
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

            AppDivider()

            // Model items
            if let providerID = selectedProviderID, let manager {
                let models = manager.models(for: providerID)
                let filteredModels = searchText.isEmpty ? models : models.filter {
                    $0.localizedCaseInsensitiveContains(searchText)
                }
                let modelInfos = selectedProviderModelInfos

                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredModels, id: \.self) { model in
                            let modelInfo = modelInfos[model]
                            let displayName = modelInfo?.displayName ?? model
                            let isSelected = model == initialModel

                            ModelListItem(
                                displayName: displayName,
                                model: model,
                                isSelected: isSelected,
                                modelInfo: modelInfo,
                                onSelect: {
                                    onSelect?(providerID, model)
                                    manager.select(providerID: providerID, model: model)
                                }
                            )
                        }
                    }
                    .padding(8)
                }
            } else {
                Spacer()
                Text("Select a provider")
                    .font(.appCallout)
                    .foregroundColor(theme.textTertiary)
                Spacer()
            }
        }
        .background(theme.background)
    }
}
