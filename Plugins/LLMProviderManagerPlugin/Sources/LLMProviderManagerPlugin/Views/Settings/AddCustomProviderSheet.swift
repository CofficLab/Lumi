import KernelLumi
import LumiUI
import SwiftUI

struct AddCustomProviderSheet: View {
    @LumiTheme private var theme
    let kernel: KernelLumi
    @Environment(\.dismiss) private var dismiss

    // MARK: - Form State

    @State private var name = ""
    @State private var id = ""
    @State private var protocolType: CustomProviderProtocol = .openAI
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var modelsText = ""
    @State private var defaultModel = ""
    @State private var errorMessage: String?

    /// Bridge between `protocolType` enum and `AppSegmentedControl`'s `Binding<Int>`.
    private var protocolIndex: Binding<Int> {
        Binding(
            get: { CustomProviderProtocol.allCases.firstIndex(of: protocolType) ?? 0 },
            set: { protocolType = CustomProviderProtocol.allCases[$0] }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    providerSection
                    modelsSection
                }
            }

            footer
        }
        .padding(24)
        .frame(width: 560, height: 580)
        .onAppear {
            if baseURL.isEmpty { baseURL = protocolType.defaultPath }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("添加云服务商")
                    .font(.title2.bold())
                Text("填写协议和模型信息后即可在当前页面使用")
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
            }
            Spacer()
            AppButton("取消", style: .ghost, size: .small) {
                dismiss()
            }
        }
    }

    // MARK: - Provider Section

    private var providerSection: some View {
        AppCard {
            AppSettingsSection(title: "供应商", subtitle: "基本信息和连接配置", spacing: 12) {
                AppSettingsRow(verticalPadding: 6) {
                    GlassTextField(title: "名称", text: $name, placeholder: "如 DeepSeek")
                }

                AppSettingsRow(verticalPadding: 6) {
                    GlassTextField(title: "唯一 ID", text: $id, placeholder: "如 my-provider")
                }

                AppSettingsRow(verticalPadding: 6) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("协议")
                            .font(DesignTokens.Typography.caption1)
                            .foregroundColor(theme.textTertiary)
                        AppSegmentedControl(
                            CustomProviderProtocol.allCases.map(\.title),
                            selection: protocolIndex,
                            maxWidth: .infinity
                        )
                    }
                }

                AppSettingsRow(verticalPadding: 6) {
                    GlassTextField(title: "Base URL", text: $baseURL, placeholder: "https://api.example.com/v1/chat/completions")
                }

                AppSettingsSecureFieldRow(
                    "API Key",
                    placeholder: "输入 API Key（可选）",
                    allowsReveal: true,
                    allowsCopy: false,
                    text: $apiKey
                )
            }
        }
    }

    // MARK: - Models Section

    private var modelsSection: some View {
        AppCard {
            AppSettingsSection(title: "模型", subtitle: "配置可用模型列表", spacing: 12) {
                AppSettingsRow(verticalPadding: 6) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("模型 ID")
                            .font(DesignTokens.Typography.caption1)
                            .foregroundColor(theme.textTertiary)
                        TextEditor(text: $modelsText)
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(theme.textPrimary)
                            .scrollContentBackground(.hidden)
                            .padding(DesignTokens.Spacing.sm)
                            .frame(minHeight: 80)
                            .background(
                                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                                    .fill(DesignTokens.Material.glass.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                            .cornerRadius(DesignTokens.Radius.sm)
                        Text("每行一个，或用逗号分隔")
                            .font(.appMicro)
                            .foregroundColor(theme.textTertiary)
                    }
                }

                AppSettingsRow(verticalPadding: 6) {
                    GlassTextField(title: "默认模型 ID（可选）", text: $defaultModel, placeholder: "留空则使用第一个模型")
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.appCaption)
                    .foregroundColor(theme.error)
            }

            HStack {
                Spacer()
                AppButton("保存供应商", systemImage: "checkmark", style: .primary) {
                    save()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    // MARK: - Save

    private func save() {
        let modelIDs = modelsText
            .components(separatedBy: .newlines)
            .flatMap { $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
            .filter { !$0.isEmpty }
        let configuration = CustomProviderConfiguration(
            id: id, name: name, protocolType: protocolType, baseURL: baseURL,
            models: modelIDs.map { CustomModelConfiguration(id: $0) }, defaultModel: defaultModel
        )
        do {
            let validated = try configuration.validated()
            guard let manager = kernel.resolveService((any LLMProviderManaging).self) as? LLMProviderManager else {
                throw CustomProviderConfiguration.ValidationError.missingName
            }
            let current = CustomProviderStore.shared.load().filter { $0.id != validated.id } + [validated]
            CustomProviderStore.shared.save(current)
            try manager.registerCustomProvider(validated)
            if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                CustomProviderStore.shared.saveAPIKey(apiKey, for: validated)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
