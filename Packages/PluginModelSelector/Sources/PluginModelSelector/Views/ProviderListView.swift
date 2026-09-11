import Foundation
import LumiUI
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
/// View 只依赖 `ModelSelectorViewModel`。
struct ProviderListView: View {
    @LumiTheme private var theme
    @ObservedObject private var viewModel: ModelSelectorViewModel
    var onClose: (() -> Void)? = nil

    init(viewModel: ModelSelectorViewModel, onClose: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onClose = onClose
    }

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
                Picker("", selection: $viewModel.selectedScope) {
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
            AppSearchBar(text: $viewModel.searchText, placeholder: LocalizedStringKey(LumiPluginLocalization.string("Search providers", bundle: .module)))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

            AppDivider()

            // Provider items
            if !viewModel.providerInfos.isEmpty {
                let providers = filteredProviders(viewModel.providerInfos)
                if providers.isEmpty && viewModel.selectedScope == .frequent && viewModel.searchText.isEmpty {
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
                            if viewModel.selectedScope == .cloud {
                                let cloudProviders = providers.filter { $0.providerType == .cloudService }
                                let relayProviders = providers.filter { $0.providerType == .relay }

                                ForEach(cloudProviders, id: \.id) { info in
                                    ProviderListItem(
                                        info: info,
                                        isSelected: info.id == viewModel.selectedProviderID,
                                        onSelect: {
                                            viewModel.selectedProviderID = info.id
                                        }
                                    )
                                }

                                if !relayProviders.isEmpty {
                                    relaySectionDivider
                                    ForEach(relayProviders, id: \.id) { info in
                                        ProviderListItem(
                                            info: info,
                                            isSelected: info.id == viewModel.selectedProviderID,
                                            onSelect: {
                                                viewModel.selectedProviderID = info.id
                                            }
                                        )
                                    }
                                }
                            } else {
                                ForEach(providers, id: \.id) { info in
                                    ProviderListItem(
                                        info: info,
                                        isSelected: info.id == viewModel.selectedProviderID,
                                        onSelect: {
                                            viewModel.selectedProviderID = info.id
                                        }
                                    )
                                }
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
            viewModel.prepareInitialScope()
            viewModel.selectProviderInCurrentScopeIfNeeded()
        }
        .onChange(of: viewModel.selectedProviderID) { _, _ in
            viewModel.synchronizeScopeWithSelection()
        }
        .onChange(of: viewModel.selectedScope) { _, _ in
            viewModel.selectProviderInCurrentScopeIfNeeded()
        }
    }

    private var relaySectionDivider: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(theme.divider)
                .frame(height: 1)
            Text("中转站")
                .font(.appMicro)
                .foregroundStyle(theme.textSecondary)
                .fixedSize()
            Rectangle()
                .fill(theme.divider)
                .frame(height: 1)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("中转站")
    }

    // MARK: - Filtering

    /// 应用筛选范围与搜索文本，返回过滤后的供应商元数据。
    private func filteredProviders(_ providers: [LLMProviderInfo]) -> [LLMProviderInfo] {
        let filtered = providers.filter(viewModel.matchesActiveFilters)
        let sorted: [LLMProviderInfo]
        if viewModel.selectedScope == .frequent {
            sorted = filtered.sorted {
                viewModel.isMoreFrequentlyUsed($0.id, than: $1.id)
            }
        } else {
            sorted = filtered.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        }
        if viewModel.searchText.isEmpty {
            return sorted
        }
        return sorted.filter {
            $0.displayName.localizedCaseInsensitiveContains(viewModel.searchText)
                || $0.id.localizedCaseInsensitiveContains(viewModel.searchText)
        }
    }
}
