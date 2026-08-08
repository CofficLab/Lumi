import Foundation
import SwiftUI
import LumiUI
import LumiKernel

/// 模型列表中的单行视图
struct ModelListItem: View {
    @LumiTheme private var theme

    let displayName: String
    let model: String
    let isSelected: Bool
    let capabilities: LumiModelCapabilities?
    let contextWindowSize: Int?
    let onSelect: () -> Void

    var body: some View {
        AppListRow(isSelected: isSelected, action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName)
                            .font(.appCallout)
                            .foregroundColor(isSelected ? theme.primary : theme.textPrimary)

                        Text(model)
                            .font(.appMicro)
                            .foregroundColor(theme.textTertiary)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(theme.primary)
                    }
                }

                if let capabilities, hasAnyCapability(capabilities) || contextWindowSize != nil {
                    capabilityRow(capabilities: capabilities, contextWindowSize: contextWindowSize)
                }
            }
        }
    }

    // MARK: - Capability Row

    private func hasAnyCapability(_ capabilities: LumiModelCapabilities) -> Bool {
        capabilities.supportsVision
            || capabilities.supportsTools
            || capabilities.supportsTTS
            || capabilities.thinkingSupport.isEnabled
    }

    @ViewBuilder
    private func capabilityRow(capabilities: LumiModelCapabilities?, contextWindowSize: Int?) -> some View {
        HStack(spacing: 6) {
            if let capabilities {
                if capabilities.supportsVision {
                    AppTag("Vision", systemImage: "eye")
                }
                if capabilities.supportsTools {
                    AppTag("Tools", systemImage: "wrench.and.screwdriver")
                }
                if capabilities.supportsTTS {
                    AppTag("TTS", systemImage: "speaker.wave.2")
                }
                if capabilities.thinkingSupport.isEnabled {
                    AppTag(thinkingTagLabel(for: capabilities.thinkingSupport), systemImage: "brain.head.profile")
                }
            }

            Spacer()

            if let contextWindowSize {
                Text(formatContextWindow(contextWindowSize))
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textTertiary)
            }
        }
    }

    /// 按档位数量显示不同文案：3 档 / 4 档模型都打 `Thinking` 标签即可。
    /// 如果未来需要区分，可在 `LumiThinkingSupport` 上加 `tagLabel` 字段。
    private func thinkingTagLabel(for support: LumiThinkingSupport) -> String {
        switch support {
        case .unsupported: ""
        case .threeLevel: "Thinking"
        case .fourLevel: "Thinking"
        }
    }

    private func formatContextWindow(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            let m = tokens / 1_000_000
            return tokens % 1_000_000 == 0 ? "\(m)M" : String(format: "%.1fM", Double(tokens) / 1_000_000.0)
        } else if tokens >= 1_000 {
            let k = tokens / 1_000
            return tokens % 1_000 == 0 ? "\(k)K" : String(format: "%.1fK", Double(tokens) / 1_000.0)
        }
        return "\(tokens)"
    }
}
