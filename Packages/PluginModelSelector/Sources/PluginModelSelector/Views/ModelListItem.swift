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
struct ModelListItem: View {
    @LumiTheme private var theme

    let displayName: String
    let model: String
    let isSelected: Bool
    let modelInfo: LLMModelInfo?
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

                if let modelInfo, hasAnyCapability(modelInfo) {
                    capabilityRow(modelInfo)
                }
            }
        }
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
