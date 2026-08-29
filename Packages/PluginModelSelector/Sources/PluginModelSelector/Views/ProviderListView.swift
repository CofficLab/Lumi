import Foundation
import LumiUI
import ProviderLLMManager
import KitLLM
import SwiftUI

/// 常用 / 云端 / 本地筛选范围。
enum ProviderScope: String, CaseIterable {
    case frequent
    case cloud
    case local

    func includes(_ provider: LLMProviderInfo, usageCount: Int = 0) -> Bool {
        switch self {
        case .frequent:
            usageCount > 0
        case .cloud:
            !provider.isLocal
        case .local:
            provider.isLocal
        }
    }
}

/// 供应商列表视图（由旧版 ModelSelectorPlugin 复刻）。
///
/// 显示所有可用的 LLM 供应商，支持搜索与云端/本地切换。
struct ProviderListView: View {
    @LumiTheme private var theme
    @ObservedObject var box: ObservableLLMProviderManagerBox
    @ObservedObject var usageStore: ProviderUsageStore
    @Binding var selectedProviderID: String?
    var onClose: (() -> Void)? = nil

    @State private var searchText = ""
    @State private var selectedScope = ProviderScope.cloud

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(LumiPluginLocalization.string("Providers", bundle: .module))
                    .font(.appCallout)
                Spacer()
                if let onClose {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(theme.surface)

            AppDivider()

            // 常用/云端/本地筛选
            HStack(spacing: 8) {
                Picker("", selection: $selectedScope) {
                    Text(LumiPluginLocalization.string("Frequent", bundle: .module))
                        .tag(ProviderScope.frequent)
                    Text(LumiPluginLocalization.string("Cloud", bundle: .module))
                        .tag(ProviderScope.cloud)
                    Text(LumiPluginLocalization.string("Local", bundle: .module))
                        .tag(ProviderScope.local)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 210)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            AppDivider()

            // Search
            AppSearchBar(text: $searchText, placeholder: LocalizedStringKey(LumiPluginLocalization.string("Search providers", bundle: .module)))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

            AppDivider()

            // Provider items
            if !box.providerInfos.isEmpty {
                let providers = filteredProviders(box.providerInfos)
                if providers.isEmpty && selectedScope == .frequent && searchText.isEmpty {
                    AppEmptyState(
                        icon: "star",
                        title: LumiPluginLocalization.string("No frequent providers yet", bundle: .module),
                        description: LumiPluginLocalization.string(
                            "As you use Lumi, your frequently used providers will appear here.",
                            bundle: .module
                        )
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(providers, id: \.id) { info in
                                ProviderListItem(
                                    info: info,
                                    isSelected: info.id == selectedProviderID,
                                    onSelect: {
                                        selectedProviderID = info.id
                                    }
                                )
                            }
                        }
                        .padding(8)
                    }
                }
            } else {
                Spacer()
                Text(LumiPluginLocalization.string("No providers available", bundle: .module))
                    .font(.appCallout)
                    .foregroundColor(theme.textTertiary)
                Spacer()
            }
        }
        .background(theme.background)
        .onAppear {
            prepareInitialScope()
            selectProviderInCurrentScopeIfNeeded()
        }
        .onChange(of: selectedProviderID) { _, _ in
            synchronizeScopeWithSelection()
        }
        .onChange(of: selectedScope) { _, _ in
            selectProviderInCurrentScopeIfNeeded()
        }
    }

    private func filteredProviders(_ providers: [LLMProviderInfo]) -> [LLMProviderInfo] {
        let filtered = providers.filter(matchesActiveFilters)
        let sorted: [LLMProviderInfo]
        if selectedScope == .frequent {
            sorted = filtered.sorted {
                usageStore.isMoreFrequentlyUsed($0.id, than: $1.id)
            }
        } else {
            sorted = filtered.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        }
        if searchText.isEmpty {
            return sorted
        }
        return sorted.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
                || $0.id.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// 常用/云端/本地筛选条件
    private func matchesActiveFilters(_ provider: LLMProviderInfo) -> Bool {
        selectedScope.includes(
            provider,
            usageCount: usageStore.usageCount(for: provider.id)
        )
    }

    private func synchronizeScopeWithSelection() {
        guard selectedScope != .frequent else { return }
        guard
            let selectedProviderID,
            let selectedProvider = box.providerInfos.first(where: { $0.id == selectedProviderID })
        else { return }

        // 仅在值变化时写入，避免触发多余的 onChange 链
        let scope: ProviderScope = selectedProvider.isLocal ? .local : .cloud
        if selectedScope != scope {
            selectedScope = scope
        }
    }

    private func prepareInitialScope() {
        let hasAvailableUsage = box.providerInfos.contains {
            usageStore.usageCount(for: $0.id) > 0
        }
        if hasAvailableUsage {
            selectedScope = .frequent
        } else {
            synchronizeScopeWithSelection()
        }
    }

    private func selectProviderInCurrentScopeIfNeeded() {
        let scopedProviders = box.providerInfos.filter(matchesActiveFilters)
        if scopedProviders.contains(where: { $0.id == selectedProviderID }) {
            return
        }
        // 仅在值变化时写入，避免触发多余的 onChange 链
        let next = scopedProviders.first?.id
        if selectedProviderID != next {
            selectedProviderID = next
        }
    }
}
