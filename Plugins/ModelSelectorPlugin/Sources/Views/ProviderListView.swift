import Foundation
import LumiKernel
import LumiUI
import SwiftUI

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

    /// 从 kernel 获取 LLMProviderManaging 服务
    private var llmProvider: (any LLMProviderManaging)? {
        kernel.resolveService((any LLMProviderManaging).self)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Providers")
                    .font(.system(size: 13, weight: .semibold))
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

            Divider()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(theme.textTertiary)
                TextField("Search providers", text: $searchText)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(theme.surface.opacity(0.5))

            Divider()

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
                    .font(.system(size: 13))
                    .foregroundColor(theme.textTertiary)
                Spacer()
            }
        }
        .background(theme.background)
    }

    private func filteredProviders(_ provider: any LLMProviderManaging) -> [LumiLLMProviderInfo] {
        let providers = provider.allLLMProviders().map { type(of: $0).info }
        if searchText.isEmpty {
            return providers
        }
        return providers.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
                || $0.id.localizedCaseInsensitiveContains(searchText)
        }
    }
}
