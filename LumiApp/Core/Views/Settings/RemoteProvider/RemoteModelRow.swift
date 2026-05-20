import LumiUI
import SwiftUI

/// 远程模型选择行组件 - 支持点击选中、默认状态标记和能力徽章展示
struct RemoteModelRow: View {
    let model: String
    let isDefault: Bool
    let supportsVision: Bool?
    let supportsTools: Bool?
    let onTap: () -> Void

    var body: some View {
        GlassRow {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 16) {
                    // 模型名称
                    Text(model)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

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
        HStack(spacing: 2) {
            Image(systemName: systemImage)
                .font(.system(size: 8, weight: .medium))
            Text(title)
                .font(.caption2)
        }
        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.adaptive(light: "6B6B7B", dark: "EBEBF5").opacity(0.12))
        )
        .help(title)
    }
}
