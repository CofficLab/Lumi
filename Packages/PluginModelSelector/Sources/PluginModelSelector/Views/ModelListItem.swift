import Foundation
import LumiUI
import ProviderLLMManager
import KitLLM
import SwiftUI

/// 模型列表中的单行视图（由旧版 ModelSelectorPlugin 复刻）。
///
/// 能力展示对齐新版 `LLMModelInfo` 元数据（Vision / Tools / 上下文窗口）；
/// 旧版 `LumiModelCapabilities` 的 TTS / 思考档位 / 参数规模字段在新版模型
/// 元数据中不存在，故不再展示。
///
/// 退役模型（`LLMModelInfo.isRetired`，即上游已不再提供）**仍可展示与选择**——
/// 保留它们是为了离线兜底底座的稳定性——但用次级文字色与「Retired」角标
/// 明确区分，避免用户选到调不通的模型。
struct ModelListItem: View {
    @LumiTheme private var theme

    let displayName: String
    let model: String
    let isSelected: Bool
    let modelInfo: LLMModelInfo?
    let onSelect: () -> Void

    /// 当前模型是否已被上游下线。
    private var isRetired: Bool { modelInfo?.isRetired == true }

    var body: some View {
        AppListRow(isSelected: isSelected, action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName)
                            .font(.appCallout)
                            .foregroundColor(titleColor)
                            .strikethrough(isRetired, color: theme.textTertiary)

                        Text(model)
                            .font(.appMicro)
                            .foregroundColor(theme.textTertiary)
                    }

                    Spacer()

                    if isRetired {
                        AppTag(pluginLocalization.string("Retired"), systemImage: "clock.badge.xmark")
                            .help(pluginLocalization.string("This model is no longer offered by the provider"))
                    }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(theme.primary)
                    }
                }

                if let modelInfo, hasAnyCapability(modelInfo) {
                    capabilityRow(modelInfo)
                }
            }
        }
        .accessibilityIdentifier("lumi.model-selector.model.\(model)")
    }

    // MARK: - Styling

    /// 标题颜色：退役模型退到次级色，仍保持与普通模型的层级差异。
    private var titleColor: Color {
        if isSelected { return theme.primary }
        return isRetired ? theme.textSecondary : theme.textPrimary
    }

    // MARK: - Capability Row

    private func hasAnyCapability(_ info: LLMModelInfo) -> Bool {
        info.supportsVision || info.supportsTools
    }

    @ViewBuilder
    private func capabilityRow(_ info: LLMModelInfo) -> some View {
        HStack(spacing: 6) {
            if info.supportsVision {
                AppTag("Vision", systemImage: "eye")
            }
            if info.supportsTools {
                AppTag("Tools", systemImage: "wrench.and.screwdriver")
            }

            Spacer()

            if let contextWindowSize = info.contextWindowSize {
                Text(formatContextWindow(contextWindowSize))
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textTertiary)
            }
        }
    }

    /// 上下文窗口按 K / M 缩写展示（与旧版一致）。
    func formatContextWindow(_ tokens: Int) -> String {
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
