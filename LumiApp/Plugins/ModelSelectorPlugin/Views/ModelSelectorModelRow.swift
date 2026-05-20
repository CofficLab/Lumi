import AppKit
import LLMKit
import SwiftUI

/// 模型选择器中的单行模型视图
/// 显示模型名称、供应商标签（可选）、上下文大小、能力 badge 和性能指标
struct ModelSelectorModelRow: View {
    /// 供应商信息
    let provider: LLMProviderInfo
    /// 模型 ID
    let model: String
    /// 可选展示名
    let displayName: String?
    /// 供应商显示名称（跨供应商列表时使用，有值则显示供应商 badge）
    let providerDisplayName: String?
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
    /// 模型可用性检测状态
    let availabilityStatus: LLMAvailabilityStatus?

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
                                    .font(.system(size: 15, weight: .regular))
                                    .lineLimit(1)

                                if let availabilityStatus {
                                    availabilityBadge(availabilityStatus)
                                }

                                if let providerDisplayName {
                                    providerBadge(providerDisplayName)
                                }

                                Spacer()
                                if let contextSize = provider.contextWindowSizes[model] {
                                    contextSizeBadge(contextSize)
                                }
                            }

                            HStack(spacing: 6) {
                                if let supportsVision {
                                    capabilityBadge(
                                        title: supportsVision
                                            ? String(localized: "Image", table: "AgentChat")
                                            : String(localized: "Text", table: "AgentChat"),
                                        systemImage: supportsVision ? "photo" : "text.bubble"
                                    )
                                }

                                if let supportsTools, supportsTools {
                                    capabilityBadge(
                                        title: String(localized: "Tools", table: "AgentChat"),
                                        systemImage: "wrench.and.screwdriver"
                                    )
                                }

                                Spacer()

                                if let stat, stat.avgTPS > 0 {
                                    tpsBadge(stat.avgTPS)
                                }

                                if let stat, stat.sampleCount > 0 {
                                    sampleCountBadge(stat.sampleCount)
                                }
                            }
                        }
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
        Text(ModelSelectorFormatService.contextSize(tokens))
            .font(.caption2)
            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.adaptive(light: "6B6B7B", dark: "EBEBF5").opacity(0.12))
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
        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.adaptive(light: "6B6B7B", dark: "EBEBF5").opacity(0.12))
        )
        .help(title)
    }

    /// 供应商标签
    private func providerBadge(_ name: String) -> some View {
        Text(name)
            .font(.caption2)
            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.adaptive(light: "6B6B7B", dark: "EBEBF5").opacity(0.12))
            )
    }

    /// 可用性状态图标。
    private func availabilityBadge(_ status: LLMAvailabilityStatus) -> some View {
        Image(systemName: availabilityIconName(for: status))
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(availabilityColor(for: status))
            .frame(width: 14, height: 14)
            .background(
                Circle()
                    .fill(availabilityColor(for: status).opacity(0.12))
            )
            .help(availabilityHelpText(for: status))
    }

    private func availabilityIconName(for status: LLMAvailabilityStatus) -> String {
        switch status {
        case .available:
            return "checkmark"
        case .unavailable:
            return "xmark"
        case .checking:
            return "ellipsis"
        case .unknown:
            return "questionmark"
        }
    }

    private func availabilityColor(for status: LLMAvailabilityStatus) -> Color {
        switch status {
        case .available:
            return Color(hex: "30D158")
        case .unavailable:
            return Color(hex: "FF3B30")
        case .checking:
            return Color(hex: "FF9F0A")
        case .unknown:
            return Color(hex: "98989E")
        }
    }

    private func availabilityHelpText(for status: LLMAvailabilityStatus) -> String {
        switch status {
        case .available:
            return String(localized: "Available", table: "LLMAvailability")
        case .unavailable(let reason):
            return reason
        case .checking:
            return String(localized: "Checking...", table: "LLMAvailability")
        case .unknown:
            return String(localized: "Unknown", table: "LLMAvailability")
        }
    }

    /// TPS badge
    private func tpsBadge(_ tps: Double) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "speedometer")
                .font(.system(size: 8, weight: .medium))
            Text(ModelSelectorFormatService.tps(tps))
                .font(.caption2)
        }
        .foregroundColor(.green)
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.green.opacity(0.12))
        )
    }

    /// 消息数量 badge
    private func sampleCountBadge(_ count: Int) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 8, weight: .medium))
            Text("\(count)")
                .font(.caption2)
        }
        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.adaptive(light: "6B6B7B", dark: "EBEBF5").opacity(0.12))
        )
    }

}
