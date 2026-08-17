import Foundation
import KernelLumi
import LumiUI
import SwiftUI

enum ProviderScope: String, CaseIterable {
    case cloud
    case local

    func includes(_ provider: LumiLLMProviderInfo) -> Bool {
        provider.isLocal == (self == .local)
    }
}

/// 供应商列表视图
///
/// 显示所有可用的 LLM 供应商，支持搜索和选择。
/// 从 kernel 自动获取 LLMProviderManaging 服务。
struct ProviderListView: View {
    @LumiTheme private var theme
    let kernel: KernelLumi
    @Binding var selectedProviderID: String?
    var onClose: (() -> Void)? = nil

    @State private var searchText = ""
    @State private var selectedScope = ProviderScope.cloud

    /// 从 kernel 获取 LLMProviderManaging 服务
    private var llmProvider: (any LLMProviderManaging)? {
        kernel.resolveService((any LLMProviderManaging).self)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Providers")
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

            // 云端/本地筛选
            HStack(spacing: 8) {
                Picker("", selection: $selectedScope) {
                    Text(LumiPluginLocalization.string("Cloud", bundle: .module))
                        .tag(ProviderScope.cloud)
                    Text(LumiPluginLocalization.string("Local", bundle: .module))
                        .tag(ProviderScope.local)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 140)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            AppDivider()

            // Search
            AppSearchBar(text: $searchText, placeholder: "Search providers")
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

            AppDivider()

            // Provider items
            if let llmProvider {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredProviders(llmProvider), id: \.id) { info in
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
            } else {
                Spacer()
                Text("No providers available")
                    .font(.appCallout)
                    .foregroundColor(theme.textTertiary)
                Spacer()
            }
        }
        .background(theme.background)
        .onAppear {
            synchronizeScopeWithSelection()
            selectProviderInCurrentScopeIfNeeded()
        }
        .onChange(of: selectedProviderID) { _, _ in
            synchronizeScopeWithSelection()
        }
        .onChange(of: selectedScope) { _, _ in
            selectProviderInCurrentScopeIfNeeded()
        }
    }

    private func filteredProviders(_ provider: any LLMProviderManaging) -> [LumiLLMProviderInfo] {
        let providers = providers(in: provider).filter(matchesActiveFilters)
        let sorted = providers.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        if searchText.isEmpty {
            return sorted
        }
        return sorted.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
                || $0.id.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// 云端/本地筛选条件
    private func matchesActiveFilters(_ provider: LumiLLMProviderInfo) -> Bool {
        selectedScope.includes(provider)
    }

    private func providers(in provider: any LLMProviderManaging) -> [LumiLLMProviderInfo] {
        provider.allLLMProviders().map { $0.providerInfo }
    }

    private func synchronizeScopeWithSelection() {
        guard
            let selectedProviderID,
            let provider = llmProvider,
            let selectedProvider = providers(in: provider).first(where: { $0.id == selectedProviderID })
        else { return }

        // 仅在值变化时写入，避免触发多余的 onChange 链
        let scope: ProviderScope = selectedProvider.isLocal ? .local : .cloud
        if selectedScope != scope {
            selectedScope = scope
        }
    }

    private func selectProviderInCurrentScopeIfNeeded() {
        guard let provider = llmProvider else { return }

        let scopedProviders = providers(in: provider).filter(matchesActiveFilters)
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
