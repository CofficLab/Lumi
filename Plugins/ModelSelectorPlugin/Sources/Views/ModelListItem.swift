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
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName)
                            .font(.system(size: 13))
                            .foregroundColor(isSelected ? theme.primary : theme.textPrimary)

                        Text(model)
                            .font(.system(size: 11))
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? theme.primary.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Capability Row

    private func hasAnyCapability(_ capabilities: LumiModelCapabilities) -> Bool {
        capabilities.supportsVision
            || capabilities.supportsTools
            || capabilities.supportsTTS
            || capabilities.supportsReasoningEffort
    }

    @ViewBuilder
    private func capabilityRow(capabilities: LumiModelCapabilities?, contextWindowSize: Int?) -> some View {
        HStack(spacing: 6) {
            if let capabilities {
                if capabilities.supportsVision {
                    capabilityBadge(icon: "eye", label: "Vision")
                }
                if capabilities.supportsTools {
                    capabilityBadge(icon: "wrench.and.screwdriver", label: "Tools")
                }
                if capabilities.supportsReasoningEffort {
                    capabilityBadge(icon: "brain", label: "Reasoning")
                }
                if capabilities.supportsTTS {
                    capabilityBadge(icon: "speaker.wave.2", label: "TTS")
                }
            }

            Spacer()

            if let contextWindowSize {
                Text(formatContextWindow(contextWindowSize))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(theme.textTertiary)
            }
        }
    }

    private func capabilityBadge(icon: String, label: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(label)
                .font(.system(size: 10))
        }
        .foregroundColor(theme.textSecondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(theme.textTertiary.opacity(0.15))
        )
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
