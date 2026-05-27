import LumiUI
import SwiftUI

/// 远程模型选择行组件 - 支持点击选中、默认状态标记和能力徽章展示
struct RemoteModelRow: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let model: String
    let isDefault: Bool
    let supportsVision: Bool?
    let supportsTools: Bool?
    let supportsTTS: Bool?
    let onTap: () -> Void

    var body: some View {
        AppSettingsRow {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 16) {
                    // 模型名称
                    Text(model)
                        .font(.appBody)
                        .foregroundColor(theme.textPrimary)

                    Spacer()

                    // 默认标记
                    if isDefault {
                        AppTag("默认", style: .accent)
                    }
                }

                HStack(spacing: 6) {
                    if let supportsVision {
                        capabilityBadge(
                            title: supportsVision
                                ? String(localized: "Image", table: "AgentInput")
                                : String(localized: "Text", table: "AgentInput"),
                            systemImage: supportsVision ? "photo" : "text.bubble"
                        )
                    }

                    if let supportsTools, supportsTools {
                        capabilityBadge(
                            title: String(localized: "Tools", table: "AgentInput"),
                            systemImage: "wrench.and.screwdriver"
                        )
                    }

                    if let supportsTTS, supportsTTS {
                        capabilityBadge(
                            title: "TTS",
                            systemImage: "waveform"
                        )
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
        }
    }

    // MARK: - Private

    @ViewBuilder
    private func capabilityBadge(title: String, systemImage: String) -> some View {
        AppTag(title, systemImage: systemImage, style: .subtle)
            .help(title)
    }
}
