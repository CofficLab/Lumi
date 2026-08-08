import Foundation
import LumiKernel
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
    let kernel: LumiKernel
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

            // Provider scope
            Picker("", selection: $selectedScope) {
                Text(LumiPluginLocalization.string("Cloud", bundle: .module))
                    .tag(ProviderScope.cloud)
                Text(LumiPluginLocalization.string("Local", bundle: .module))
                    .tag(ProviderScope.local)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .padding(.horizontal, 8)
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
        }
        .onChange(of: selectedProviderID) { _, _ in
            synchronizeScopeWithSelection()
        }
        .onChange(of: selectedScope) { _, _ in
            selectProviderInCurrentScopeIfNeeded()
        }
    }

    private func filteredProviders(_ provider: any LLMProviderManaging) -> [LumiLLMProviderInfo] {
        let providers = providers(in: provider).filter(selectedScope.includes)
        let sorted = providers.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        if searchText.isEmpty {
            return sorted
        }
        return sorted.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
                || $0.id.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func providers(in provider: any LLMProviderManaging) -> [LumiLLMProviderInfo] {
        provider.allLLMProviders().map { type(of: $0).info }
    }

    private func synchronizeScopeWithSelection() {
        guard
            let selectedProviderID,
            let provider = llmProvider,
            let selectedProvider = providers(in: provider).first(where: { $0.id == selectedProviderID })
        else { return }

        selectedScope = selectedProvider.isLocal ? .local : .cloud
    }

    private func selectProviderInCurrentScopeIfNeeded() {
        guard let provider = llmProvider else { return }

        let scopedProviders = providers(in: provider).filter(selectedScope.includes)
        if scopedProviders.contains(where: { $0.id == selectedProviderID }) {
            return
        }
        selectedProviderID = scopedProviders.first?.id
    }
}
