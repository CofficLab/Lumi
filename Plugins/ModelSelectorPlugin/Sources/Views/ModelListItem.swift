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
            || capabilities.supportsReasoningEffort
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
                if capabilities.supportsReasoningEffort {
                    AppTag("Reasoning", systemImage: "brain")
                }
                if capabilities.supportsTTS {
                    AppTag("TTS", systemImage: "speaker.wave.2")
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
