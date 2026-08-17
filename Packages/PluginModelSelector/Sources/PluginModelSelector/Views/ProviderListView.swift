import Foundation
import LumiUI
import ProviderLLMManager
import ProviderLLMVendors
import SwiftUI

/// 云端 / 本地筛选范围（由旧版复刻，作用于 `LLMProviderInfo.isLocal`）。
enum ProviderScope: String, CaseIterable {
    case cloud
    case local

    func includes(_ provider: LLMProviderInfo) -> Bool {
        provider.isLocal == (self == .local)
    }
}

/// 供应商列表视图（由旧版 ModelSelectorPlugin 复刻）。
///
/// 显示所有可用的 LLM 供应商，支持搜索、云端/本地切换与 API 格式筛选。
struct ProviderListView: View {
    @LumiTheme private var theme
    @ObservedObject var box: ObservableLLMProviderManagerBox
    @Binding var selectedProviderID: String?
    var onClose: (() -> Void)? = nil

    @State private var searchText = ""
    @State private var selectedScope = ProviderScope.cloud
    /// 默认按 OpenAI 格式筛选；nil 表示全部格式
    @State private var selectedFormat: LLMProviderAPIFormat? = .openAI

    private var manager: (any LLMManaging)? { box.manager }

    /// API 格式筛选（菜单）。独立为计算属性以减小 body 的类型推断复杂度。
    @ViewBuilder
    private var formatFilter: some View {
        HStack(spacing: 4) {
            Text(LumiPluginLocalization.string("Format", bundle: .module))
                .font(.appMicro)
                .foregroundColor(theme.textTertiary)
            Picker("", selection: $selectedFormat) {
                Text(LumiPluginLocalization.string("All Formats", bundle: .module))
                    .tag(Optional<LLMProviderAPIFormat>.none)
                ForEach(LLMProviderAPIFormat.allCases, id: \.self) { format in
                    Text(format.displayName)
                        .tag(Optional<LLMProviderAPIFormat>.some(format))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
        .fixedSize()
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

            // 云端/本地 + 格式筛选：同一行，一左一右
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

                formatFilter
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
            if let manager {
                let providers = filteredProviders(manager)
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
        .onChange(of: selectedFormat) { _, _ in
            selectProviderInCurrentScopeIfNeeded()
        }
    }

    private func filteredProviders(_ manager: any LLMManaging) -> [LLMProviderInfo] {
        let providers = providers(in: manager).filter(matchesActiveFilters)
        let sorted = providers.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        if searchText.isEmpty {
            return sorted
        }
        return sorted.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
                || $0.id.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// 云端/本地 + API 格式的组合筛选条件
    private func matchesActiveFilters(_ provider: LLMProviderInfo) -> Bool {
        selectedScope.includes(provider)
            && (selectedFormat == nil || provider.apiFormat == selectedFormat)
    }

    private func providers(in manager: any LLMManaging) -> [LLMProviderInfo] {
        manager.allProviders().map { $0.providerInfo }
    }

    private func synchronizeScopeWithSelection() {
        guard
            let selectedProviderID,
            let manager,
            let selectedProvider = providers(in: manager).first(where: { $0.id == selectedProviderID })
        else { return }

        // 仅在值变化时写入，避免触发多余的 onChange 链
        let scope: ProviderScope = selectedProvider.isLocal ? .local : .cloud
        if selectedScope != scope {
            selectedScope = scope
        }
    }

    private func selectProviderInCurrentScopeIfNeeded() {
        guard let manager else { return }

        let scopedProviders = providers(in: manager).filter(matchesActiveFilters)
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
