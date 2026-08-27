import Foundation
import LumiUI
import ProviderLLMManager
import KitLLM
import SwiftUI

/// 单个供应商的详情视图（API Key 段 + 模型段）。
///
/// - 云端供应商：API Key 读写/删除 + 模型列表（点击切换选中模型）；
/// - 本地供应商：仅模型列表（无需 API Key）。
@MainActor
public struct ProviderDetailView: View {
    @LumiTheme private var theme

    private let manager: any LLMManaging
    private let provider: any SuperLLMProvider

    @State private var apiKey: String = ""
    @State private var savedAPIKey: String = ""
    @State private var apiKeySaveError: String?

    public init(manager: any LLMManaging, provider: any SuperLLMProvider) {
        self.manager = manager
        self.provider = provider
    }

    private var info: LLMProviderInfo { provider.providerInfo }
    private var isLocal: Bool { info.isLocal }

    private var isSelectedProvider: Bool {
        manager.selectedProviderID == info.id
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            if !isLocal {
                apiKeySection
            }
            if let downloader = provider as? any LLMModelDownloadProviding {
                ProviderModelDownloadView(
                    models: info.models,
                    downloader: downloader,
                    onSelectModel: { modelID in
                        manager.select(providerID: info.id, model: modelID)
                    },
                    isModelSelected: { modelID in
                        manager.selectedProviderID == info.id && manager.selectedModel == modelID
                    }
                )
            } else {
                modelSection
            }
        }
        .onAppear {
            loadAPIKey()
        }
        .onChange(of: provider.providerInfo.id) { _, _ in
            loadAPIKey()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: isLocal ? "cpu" : "cloud.fill")
                    .font(.title3)
                    .foregroundStyle(theme.primary)
                Text(info.displayName)
                    .font(.appTitle)
                if isLocal {
                    AppTag("本地", systemImage: "cpu")
                }
                Spacer()
                if let url = info.websiteURL {
                    Link(destination: url) {
                        AppTag("访问官网", systemImage: "arrow.up.right.square", style: .accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            if !info.description.isEmpty {
                Text(info.description)
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
            }
            Text(info.id)
                .font(.appMicro)
                .foregroundStyle(theme.textTertiary)
                .textSelection(.enabled)
        }
    }

    // MARK: - API Key Section

    private var apiKeySection: some View {
        AppSettingsSection(title: "API 密钥", subtitle: "配置访问凭证") {
            AppSettingsSecureFieldRow(
                "API Key",
                placeholder: "输入 API Key",
                allowsReveal: true,
                allowsCopy: true,
                text: $apiKey
            )
            .id(info.id)

            HStack(spacing: 8) {
                AppButton(LumiPluginLocalization.string("Save API Key", bundle: .module), systemImage: "checkmark", style: .primary, size: .small) {
                    saveAPIKey()
                }
                .disabled(
                    apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || apiKey == savedAPIKey
                )

                if !savedAPIKey.isEmpty {
                    AppButton(LumiPluginLocalization.string("Delete API Key", bundle: .module), systemImage: "trash", style: .destructive, size: .small) {
                        removeAPIKey()
                    }
                }

                if !savedAPIKey.isEmpty, apiKey == savedAPIKey {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(theme.success)
                        Text("已保存")
                            .font(.appCaption)
                            .foregroundColor(theme.success)
                    }
                }
            }

            if let apiKeySaveError {
                Text(apiKeySaveError)
                    .font(.appCaption)
                    .foregroundStyle(theme.error)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - Model Section

    private var modelSection: some View {
        AppSettingsSection(
            title: "可用模型",
            subtitle: isSelectedProvider ? "当前供应商已选中" : "点击模型以切换选中"
        ) {
            ForEach(info.models, id: \.id) { model in
                modelRow(model)
            }
        }
    }

    private func modelRow(_ model: LLMModelInfo) -> some View {
        let isSelectedModel = isSelectedProvider && manager.selectedModel == model.id
        return AppSettingsRow(isSelected: isSelectedModel, horizontalPadding: 10, verticalPadding: 10) {
            HStack(spacing: 10) {
                Image(systemName: isSelectedModel ? "checkmark.circle.fill" : "circle")
                    .font(.appCallout)
                    .foregroundStyle(isSelectedModel ? theme.primary : theme.textTertiary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName)
                        .font(.appBody)
                        .foregroundStyle(theme.textPrimary)
                    if let context = model.contextWindowSize {
                        Text("上下文 \(Self.formatted(context))")
                            .font(.appMicro)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if model.supportsVision {
                    AppTag("视觉", systemImage: "eye")
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            manager.select(providerID: info.id, model: model.id)
        }
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - API Key Actions

    private func loadAPIKey() {
        savedAPIKey = provider.getApiKey()
        apiKey = savedAPIKey
        apiKeySaveError = nil
    }

    private func saveAPIKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        provider.setApiKey(trimmed)
        savedAPIKey = trimmed
        apiKey = trimmed
        apiKeySaveError = nil
    }

    private func removeAPIKey() {
        provider.removeApiKey()
        savedAPIKey = ""
        apiKey = ""
        apiKeySaveError = nil
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
