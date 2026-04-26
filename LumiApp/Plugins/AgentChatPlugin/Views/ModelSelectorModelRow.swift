import AppKit
import MagicKit
import SwiftUI

/// 模型选择器中的单行模型视图
/// 显示模型名称、上下文大小、能力 badge 和性能条
struct ModelSelectorModelRow: View {
    /// 供应商信息
    let provider: LLMProviderInfo
    /// 模型 ID
    let model: String
    /// 可选展示名
    let displayName: String?
    /// 是否支持视觉
    let supportsVision: Bool?
    /// 是否支持工具
    let supportsTools: Bool?
    /// 是否为当前选中模型
    let isSelected: Bool
    /// 是否为 hover 状态
    let isHovering: Bool
    /// 详细性能统计
    let stat: ModelPerformanceStats?

    /// 点击选择回调
    let onSelect: () -> Void
    /// Hover 状态变更回调
    let onHoverChange: (Bool) -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(displayName ?? model)
                                    .font(AppUI.Typography.body)
                                    .lineLimit(1)

                                Spacer()
                                if let contextSize = provider.contextWindowSizes[model] {
                                    contextSizeBadge(contextSize)
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
                    }
                    if let stat, stat.avgTTFT > 0 {
                        ModelLatencyProgressBar(
                            ttft: stat.avgTTFT,
                            totalLatency: stat.avgLatency,
                            sampleCount: stat.sampleCount,
                            tps: stat.avgTPS
                        )
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(rowBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            onHoverChange(hovering)
            if hovering {
                if !isSelected {
                    NSCursor.pointingHand.push()
                }
            } else {
                NSCursor.pop()
            }
        }
    }

    // MARK: - Helper

    /// 行背景色
    private var rowBackgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.15)
        }
        if isHovering {
            return Color.accentColor.opacity(0.08)
        }
        return Color.clear
    }

    /// 上下文窗口大小标签
    private func contextSizeBadge(_ tokens: Int) -> some View {
        Text(formatContextSize(tokens))
            .font(.caption2)
            .foregroundColor(AppUI.Color.semantic.textSecondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(AppUI.Color.semantic.textSecondary.opacity(0.12))
            )
    }

    /// 能力 badge
    private func capabilityBadge(title: String, systemImage: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: systemImage)
                .font(.system(size: 8, weight: .medium))
            Text(title)
                .font(.caption2)
        }
        .foregroundColor(AppUI.Color.semantic.textSecondary)
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(AppUI.Color.semantic.textSecondary.opacity(0.12))
        )
        .help(title)
    }

    /// 格式化上下文窗口大小
    private func formatContextSize(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            let value = Double(tokens) / 1_000_000.0
            return value == floor(value) ? "\(Int(value))M" : String(format: "%.1fM", value)
        } else if tokens >= 1_000 {
            let value = Double(tokens) / 1_000.0
            return value == floor(value) ? "\(Int(value))K" : String(format: "%.0fK", value)
        } else {
            return "\(tokens)"
        }
    }
}
