import Foundation
import LumiKernel
import LumiUI
import SwiftUI

/// 供应商设置页面基础组件
///
/// 提供搜索侧边栏 + 详情面板的主从布局，由远程/本地设置页复用。
/// `selectedProviderID` 通过 Binding 暴露给父视图。
struct ProviderSettingsPage<DetailContent: View>: View {
    @LumiTheme private var theme
    let kernel: LumiKernel

    let title: String
    let systemIcon: String
    let localizedProvidersKey: String
    let isLocalProvider: (LumiLLMProviderInfo) -> Bool
    @Binding var selectedProviderID: String
    let headerAccessory: AnyView?
    let detailContent: (LumiLLMProviderInfo) -> DetailContent

    @State private var searchText: String = ""

    private let settingsStore = ProviderSettingsStore.shared
    private var llmProvider: (any LLMProviderManaging)? {
        kernel.resolveService((any LLMProviderManaging).self)
    }

    private var providers: [LumiLLMProviderInfo] {
        (llmProvider?.allLLMProviders().map { type(of: $0).info } ?? []).filter(isLocalProvider)
    }

    private var selectedProvider: LumiLLMProviderInfo? {
        providers.first { $0.id == selectedProviderID }
    }

    private var filteredProviders: [LumiLLMProviderInfo] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return providers }
        return providers.filter {
            $0.displayName.localizedCaseInsensitiveContains(keyword)
                || $0.description.localizedCaseInsensitiveContains(keyword)
                || $0.id.localizedCaseInsensitiveContains(keyword)
        }
    }

    var body: some View {
        AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 14) {
                headerStats

                HStack(spacing: 0) {
                    providerSidebar
                        .frame(width: 300)
                        .frame(maxHeight: .infinity)

                    AppDivider(.vertical)

                    providerDetailPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(minHeight: 520, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.divider, lineWidth: 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear(perform: onAppear)
        .onChange(of: filteredProviders.map(\.id)) { _, ids in
            if !ids.contains(selectedProviderID) {
                selectedProviderID = ids.first ?? ""
            }
        }
        .onChange(of: selectedProviderID) { _, newValue in
            persistSelection(newValue)
        }
    }

    // MARK: - Header

    private var headerStats: some View {
        HStack(spacing: 10) {
            Label(
                String(format: localizedProvidersKey, providers.count),
                systemImage: systemIcon
            )
            Text(String(format: "%lld models", selectedProvider?.availableModels.count ?? 0))
            Spacer()
            if let headerAccessory {
                headerAccessory
            }
        }
        .font(.appCaption)
        .foregroundStyle(theme.textSecondary)
    }

    // MARK: - Sidebar

    private var providerSidebar: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                AppSearchBar(
                    text: $searchText,
                    placeholder: LocalizedStringKey(LumiPluginLocalization.string("Search providers"))
                )
            }
            .padding(12)

            AppDivider()

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredProviders) { provider in
                        providerListRow(provider)
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

    private func providerListRow(_ provider: LumiLLMProviderInfo) -> some View {
        let isSelected = selectedProviderID == provider.id
        return AppListRow(isSelected: isSelected, action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedProviderID = provider.id
            }
        }) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemIcon)
                    .font(.appBody)
                    .foregroundStyle(isSelected ? theme.primary : theme.textSecondary)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(provider.displayName)
                        .font(.appCaptionEmphasized)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    Text(provider.description.isEmpty ? provider.id : provider.description)
                        .font(.appMicro)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Detail Pane

    @ViewBuilder
    private var providerDetailPane: some View {
        if let provider = selectedProvider {
            ScrollView {
                detailContent(provider)
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appSurface(style: .panel, cornerRadius: 0)
        } else {
            AppEmptyState(icon: systemIcon, title: "选择一个供应商")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .appSurface(style: .panel, cornerRadius: 0)
        }
    }

    // MARK: - Lifecycle

    private func onAppear() {
        loadSelectedProviderID()
        triggerAvailabilityCheck()
    }

    private func loadSelectedProviderID() {
        let savedID: String?
        if providers.first?.isLocal == true {
            savedID = settingsStore.loadSelectedLocalProviderID()
        } else {
            savedID = settingsStore.loadSelectedRemoteProviderID()
        }

        if let savedID, providers.contains(where: { $0.id == savedID }) {
            selectedProviderID = savedID
        } else if let first = providers.first {
            selectedProviderID = first.id
        }
    }

    private func persistSelection(_ id: String) {
        if providers.first?.isLocal == true {
            settingsStore.saveSelectedLocalProviderID(id)
        } else {
            settingsStore.saveSelectedRemoteProviderID(id)
        }
    }

    private func triggerAvailabilityCheck() {
        guard let manager = kernel.resolveService((any LLMProviderManaging).self) as? LLMProviderManager else { return }
        let items: [(info: LumiLLMProviderInfo, instance: any LumiLLMProvider)] =
            providers.compactMap { info in
                guard let instance = manager.llmProvider(id: info.id) else { return nil }
                return (info, instance)
            }
        guard !items.isEmpty else { return }
        Task { await manager.providerAvailabilityState.checkAll(items) }
    }
}
