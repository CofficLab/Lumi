import Foundation
import LumiUI
import KitLLM
import SwiftUI

/// 单个供应商的详情视图（API Key 段 + 模型段）。
///
/// - 云端供应商：API Key 读写/删除 + 模型列表（点击切换选中模型）；
/// - 本地供应商：仅模型列表（无需 API Key）。
///
/// View 只依赖 `ProviderDetailViewModel`，不再直接持有 manager / Provider / Store，
/// 也不对外部 Provider 做 downcast（下载能力由 ViewModel 解析）。
@MainActor
public struct ProviderDetailView: View {
    @LumiTheme private var theme

    @ObservedObject private var viewModel: ProviderDetailViewModel
    @State private var isEditorPresented = false
    @State private var isDeleteConfirmationPresented = false

    init(viewModel: ProviderDetailViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            if !viewModel.isLocal {
                apiKeySection
            }
            if let downloadViewModel = viewModel.downloadViewModel,
               let capability = viewModel.downloadCapability {
                ProviderModelDownloadView(
                    models: viewModel.models,
                    capability: capability,
                    viewModel: downloadViewModel,
                    onSelectModel: { modelID in
                        viewModel.select(modelID: modelID)
                    },
                    isModelSelected: { modelID in
                        viewModel.isModelSelected(modelID)
                    }
                )
            } else {
                modelSection
            }
        }
        .sheet(isPresented: $isEditorPresented) {
            if let editor = viewModel.makeCustomProviderEditor() {
                editor
                    .frame(width: 580, height: 640)
            }
        }
        .confirmationDialog(
            "删除自定义供应商？",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                viewModel.removeCustomProvider()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这会移除供应商配置和对应的 API Key。")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: viewModel.isLocal ? "cpu" : "cloud.fill")
                    .font(.title3)
                    .foregroundStyle(theme.primary)
                Text(viewModel.displayName)
                    .font(.appTitle)
                Spacer()
                if let url = viewModel.websiteURL {
                    Link(destination: url) {
                        AppTag("访问官网", systemImage: "arrow.up.right.square", style: .accent)
                    }
                    .buttonStyle(.plain)
                }
                if viewModel.canEditCustomProvider {
                    AppButton("编辑", systemImage: "pencil", style: .secondary, size: .small) {
                        isEditorPresented = true
                    }
                    AppButton("删除", systemImage: "trash", style: .destructive, size: .small) {
                        isDeleteConfirmationPresented = true
                    }
                }
            }
            if !viewModel.providerDescription.isEmpty {
                Text(viewModel.providerDescription)
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
            }
            Text(viewModel.providerID)
                .font(.appMicro)
                .foregroundStyle(theme.textTertiary)
                .textSelection(.enabled)
        }
    }

    // MARK: - API Key Section

    private var apiKeySection: some View {
        AppSettingSection(title: "API 密钥") {
            VStack(spacing: 0) {
                AppSettingRow(
                    title: "API Key",
                    description: "配置访问凭证",
                    icon: "key"
                ) {
                    SecureField("输入 API Key", text: $viewModel.apiKey)
                        .textFieldStyle(.plain)
                        .font(.appBody)
                        .frame(width: 280)
                }

                Divider()
                    .padding(.vertical, 8)

                AppSettingRow(
                    title: "操作",
                    description: viewModel.savedAPIKey.isEmpty ? "尚未保存 API Key" : "已保存 API Key"
                ) {
                    HStack(spacing: 8) {
                        AppButton("保存", systemImage: "checkmark", style: .primary, size: .small) {
                            viewModel.saveAPIKey()
                        }
                        .disabled(
                            viewModel.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || viewModel.apiKey == viewModel.savedAPIKey
                        )

                        if !viewModel.savedAPIKey.isEmpty {
                            AppButton("删除", systemImage: "trash", style: .destructive, size: .small) {
                                viewModel.removeAPIKey()
                            }
                        }

                        if !viewModel.savedAPIKey.isEmpty, viewModel.apiKey == viewModel.savedAPIKey {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(theme.success)
                                    .font(.appCaption)
                                Text("已保存")
                                    .font(.appCaption)
                                    .foregroundColor(theme.success)
                            }
                        }
                    }
                }

                if let apiKeySaveError = viewModel.apiKeySaveError {
                    Divider()
                        .padding(.vertical, 8)

                    AppSettingRow(
                        title: "错误",
                        description: apiKeySaveError
                    ) {
                        EmptyView()
                    }
                    .foregroundColor(theme.error)
                }
            }
        }
    }

    // MARK: - Model Section

    private var modelSection: some View {
        AppSettingSection(title: "可用模型") {
            VStack(spacing: 0) {
                ForEach(viewModel.models.enumerated().map({ $0 }), id: \.element.id) { index, model in
                    if index > 0 {
                        Divider()
                            .padding(.vertical, 4)
                    }
                    modelRow(model)
                }
            }
        }
    }

    private func modelRow(_ model: LLMModelInfo) -> some View {
        let isSelected = viewModel.isModelSelected(model.id)
        return AppSettingRow(
            title: model.displayName,
            description: model.contextWindowSize.map { "上下文 \(Self.formatted($0))" },
            icon: isSelected ? "checkmark.circle.fill" : (model.supportsVision ? "eye" : "cpu")
        ) {
            HStack(spacing: 6) {
                if model.supportsVision {
                    AppTag("视觉", systemImage: "eye", style: .accent)
                }
                if isSelected {
                    AppTag("当前", systemImage: "checkmark", style: .accent)
                }
            }
        }
        .onTapGesture {
            viewModel.select(modelID: model.id)
        }
    }

    // MARK: - Helpers

    private static func formatted(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            let m = Double(tokens) / 1_000_000
            return String(format: "%.1fM", m)
        }
        if tokens >= 1_000 {
            return "\(tokens / 1_000)K"
        }
        return "\(tokens)"
    }
}
