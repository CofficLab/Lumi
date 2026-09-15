import Foundation
import LumiUI
import KitLLM
import SwiftUI

/// 本地和云端供应商页面共用的主从布局内容。
///
/// View 只依赖 `ProviderSettingsPageViewModel`，供应商列表、搜索、
/// 选中态与自定义供应商变化都由 ViewModel 提供。
@MainActor
struct ProviderSettingsPageContent: View {
    @LumiTheme private var theme

    @ObservedObject private var viewModel: ProviderSettingsPageViewModel
    @State private var isCustomProviderEditorPresented = false

    init(viewModel: ProviderSettingsPageViewModel) {
        self.viewModel = viewModel
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
        .sheet(isPresented: $isCustomProviderEditorPresented) {
            if let editor = viewModel.makeNewCustomProviderEditor() {
                editor
                    .frame(width: 560, height: 620)
            }
        }
        .onAppear {
            viewModel.synchronizeSelection()
        }
        .onChange(of: viewModel.customProviderRevision) { _, _ in
            viewModel.synchronizeSelection()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Label(
                viewModel.providerCountLabel,
                systemImage: viewModel.headerSystemImage
            )
            Text("\(viewModel.selectedModelCount) 个模型")
            Spacer()
            if !viewModel.isLocal {
                AppButton("添加供应商", systemImage: "plus", style: .primary, size: .small) {
                    isCustomProviderEditorPresented = true
                }
            }
        }
        .font(.appCaption)
        .foregroundStyle(theme.textSecondary)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            AppSearchBar(text: $viewModel.searchText, placeholder: "搜索供应商")
                .padding(12)

            AppDivider()

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(viewModel.filteredProviders, id: \.providerInfo.id) { provider in
                        providerRow(provider)
                    }
                    if viewModel.filteredProviders.isEmpty {
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
        let isSelected = viewModel.selectedProviderID == info.id
        return AppListRow(isSelected: isSelected, action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectProvider(id: info.id)
            }
        }) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: viewModel.headerSystemImage)
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
        if let selectedProviderID = viewModel.selectedProviderID {
            ScrollView {
                ProviderDetailView(viewModel: viewModel.detailViewModel(for: selectedProviderID))
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appSurface(style: .panel, cornerRadius: 0)
        } else {
            AppEmptyState(icon: viewModel.headerSystemImage, title: "选择一个供应商")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .appSurface(style: .panel, cornerRadius: 0)
        }
    }
}
