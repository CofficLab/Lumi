import LumiCoreMessage
import LumiKernel
import LumiUI
import SwiftUI

public struct CodexLocalProviderSettingsView: View {
    @LumiTheme private var theme

    let provider: LumiLLMProviderInfo
    @State private var cli: CodexCLI

    public init(provider: LumiLLMProviderInfo) {
        self.provider = provider
        self._cli = State(initialValue: CodexCLI())
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            cliStatusCard
            modelListCard
        }
    }

    private var cliStatusCard: some View {
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

    private var modelListCard: some View {
        AppSettingsSection(title: "可用模型", spacing: 12) {
            VStack(spacing: 0) {
                ForEach(Array(provider.availableModels.enumerated()), id: \.element) { index, model in
                    AppListRow {
                        readOnlyModelRow(
                            model: model,
                            supportsVision: provider.modelCapabilities[model]?.supportsVision,
                            supportsTools: provider.modelCapabilities[model]?.supportsTools,
                            supportsTTS: provider.modelCapabilities[model]?.supportsTTS
                        )
                    }

                    if index < provider.availableModels.count - 1 {
                        AppSettingsDivider()
                            .padding(.horizontal, 8)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func readOnlyModelRow(
        model: String,
        supportsVision: Bool?,
        supportsTools: Bool?,
        supportsTTS: Bool?
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model)
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if supportsVision != nil || supportsTools == true || supportsTTS == true {
                HStack(spacing: 6) {
                    if let supportsVision {
                        AppTag(
                            supportsVision ? "Image" : "Text",
                            systemImage: supportsVision ? "photo" : "text.bubble",
                            style: .subtle
                        )
                    }
                    if supportsTools == true {
                        AppTag("Tools", systemImage: "wrench.and.screwdriver", style: .subtle)
                    }
                    if supportsTTS == true {
                        AppTag("TTS", systemImage: "waveform", style: .subtle)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}
