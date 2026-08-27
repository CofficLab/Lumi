import Foundation
import LumiUI
import ProviderLLMManager
import KitLLM
import SwiftUI

/// 本地和云端供应商页面共用的主从布局内容。
@MainActor
struct ProviderSettingsPageContent: View {
    @LumiTheme private var theme

    private let manager: any LLMManaging
    private let isLocal: Bool

    @State private var selectedProviderID: String?
    @State private var searchText: String = ""

    init(manager: any LLMManaging, isLocal: Bool) {
        self.manager = manager
        self.isLocal = isLocal
    }

    private var allProviders: [any SuperLLMProvider] {
        manager.allProviders()
    }

    private var filteredProviders: [any SuperLLMProvider] {
        let scope = allProviders.filter { $0.providerInfo.isLocal == isLocal }
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return scope }
        return scope.filter {
            $0.providerInfo.displayName.localizedCaseInsensitiveContains(keyword)
                || $0.providerInfo.description.localizedCaseInsensitiveContains(keyword)
                || $0.providerInfo.id.localizedCaseInsensitiveContains(keyword)
        }
    }

    private var selectedProvider: (any SuperLLMProvider)? {
        guard let selectedProviderID else { return nil }
        return filteredProviders.first { $0.providerInfo.id == selectedProviderID }
    }

    private var selectedModelCount: Int {
        selectedProvider?.providerInfo.models.count ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 280)
                    .frame(maxHeight: .infinity)
                AppDivider(.vertical)
                detailPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(minHeight: 460, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(theme.divider, lineWidth: 1)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: filteredProviders.map(\.providerInfo.id)) { _, ids in
            if let selectedProviderID, !ids.contains(selectedProviderID) {
                self.selectedProviderID = ids.first
            } else if selectedProviderID == nil {
                selectedProviderID = ids.first
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Label(
                isLocal ? "\(filteredProviders.count) 个本地供应商" : "\(filteredProviders.count) 个云端供应商",
                systemImage: isLocal ? "cpu" : "cloud"
            )
            Text("\(selectedModelCount) 个模型")
            Spacer()
        }
        .font(.appCaption)
        .foregroundStyle(theme.textSecondary)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            AppSearchBar(text: $searchText, placeholder: "搜索供应商")
                .padding(12)

            AppDivider()

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredProviders, id: \.providerInfo.id) { provider in
                        providerRow(provider)
                    }
                    if filteredProviders.isEmpty {
                        AppEmptyState(icon: "magnifyingglass", title: "未找到供应商")
                            .padding(.vertical, 32)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: .infinity)
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private func providerRow(_ provider: any SuperLLMProvider) -> some View {
        let info = provider.providerInfo
        let isSelected = selectedProviderID == info.id
        return AppListRow(isSelected: isSelected, action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedProviderID = info.id
            }
        }) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isLocal ? "cpu" : "cloud")
                    .font(.appBody)
                    .foregroundStyle(isSelected ? theme.primary : theme.textSecondary)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(info.displayName)
                        .font(.appCaptionEmphasized)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    Text(info.description.isEmpty ? info.id : info.description)
                        .font(.appMicro)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let selectedProvider {
            ScrollView {
                ProviderDetailView(manager: manager, provider: selectedProvider)
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appSurface(style: .panel, cornerRadius: 0)
        } else {
            AppEmptyState(icon: isLocal ? "cpu" : "cloud", title: "选择一个供应商")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .appSurface(style: .panel, cornerRadius: 0)
        }
    }
}
