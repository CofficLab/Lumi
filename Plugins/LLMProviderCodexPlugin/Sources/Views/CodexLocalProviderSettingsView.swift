import LumiCoreKit
import LumiUI
import SwiftUI

public struct CodexLocalProviderSettingsView: View {
    @LumiTheme private var theme

    let provider: LumiLLMProviderInfo
    @State private var selectedModelID: String
    @State private var cli: CodexCLI

    private let onDefaultModelChanged: (String) -> Void

    public init(
        provider: LumiLLMProviderInfo,
        initialDefaultModelID: String,
        onDefaultModelChanged: @escaping (String) -> Void
    ) {
        self.provider = provider
        self._selectedModelID = State(initialValue: initialDefaultModelID)
        self._cli = State(initialValue: CodexCLI())
        self.onDefaultModelChanged = onDefaultModelChanged
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            cliStatusCard
            modelListCard
        }
    }

    private var cliStatusCard: some View {
        AppCard {
            AppSettingsSection(title: "Codex CLI", subtitle: "通过本地 Codex 命令行调用 OpenAI 模型", spacing: 12) {
                HStack {
                    Text("可执行文件")
                        .font(.appBody)
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                    Text(cli.executablePath)
                        .font(.appMonoCaption)
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                HStack(spacing: 8) {
                    Image(systemName: cli.isAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(cli.isAvailable ? theme.success : theme.warning)
                    Text(cli.isAvailable ? "CLI 已就绪" : "未找到 Codex CLI，请先安装并加入 PATH")
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                }
            }
        }
    }

    private var modelListCard: some View {
        AppCard {
            AppSettingsSection(title: "可用模型", subtitle: "点击某个模型可设为默认", spacing: 12) {
                VStack(spacing: 0) {
                    ForEach(Array(provider.availableModels.enumerated()), id: \.element) { index, model in
                        AppSettingsModelRow(
                            model: model,
                            isDefault: selectedModelID == model
                        ) {
                            selectedModelID = model
                            onDefaultModelChanged(model)
                        }

                        if index < provider.availableModels.count - 1 {
                            AppSettingsDivider()
                                .padding(.horizontal, 8)
                        }
                    }
                }
            }
        }
    }
}

