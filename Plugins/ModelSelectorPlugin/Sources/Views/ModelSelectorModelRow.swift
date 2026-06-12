import AppKit
import LLMKit
import SwiftUI
import LumiUI
import LumiCoreKit

/// 模型选择器中的单行模型视图
/// 显示模型名称、供应商标签（可选）、上下文大小、能力 badge 和性能指标
public struct ModelSelectorModelRow: View {
    /// 供应商信息
    public let provider: LLMProviderInfo
    /// 模型 ID
    public let model: String
    /// 可选展示名
    public let displayName: String?
    /// 供应商显示名称（跨供应商列表时使用，有值则显示供应商 badge）
    public let providerDisplayName: String?
    /// 是否支持视觉
    public let supportsVision: Bool?
    /// 是否支持工具
    public let supportsTools: Bool?
    /// 是否支持文本转语音（TTS）
    public let supportsTTS: Bool?
    /// 是否为当前选中模型
    public let isSelected: Bool
    /// 是否为 hover 状态
    public let isHovering: Bool
    /// 详细性能统计
    public let stat: ModelPerformanceStats?
    /// 模型可用性检测状态
    public let availabilityStatus: LLMAvailabilityStatus?

    /// 点击选择回调
    public let onSelect: () -> Void
    /// Hover 状态变更回调
    public let onHoverChange: (Bool) -> Void

    public var body: some View {
        AppListRow(isSelected: isSelected, action: onSelect) {
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
                                            ? LumiPluginLocalization.string("Image", bundle: .module)
                                            : LumiPluginLocalization.string("Text", bundle: .module),
                                        systemImage: supportsVision ? "photo" : "text.bubble"
                                    )
                                }

                                if let supportsTools, supportsTools {
                                    capabilityBadge(
                                        title: LumiPluginLocalization.string("Tools", bundle: .module),
                                        systemImage: "wrench.and.screwdriver"
                                    )
                                }

                                if let supportsTTS, supportsTTS {
                                    capabilityBadge(
                                        title: LumiPluginLocalization.string("TTS", bundle: .module),
                                        systemImage: "waveform"
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
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
        }
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

    /// 上下文窗口大小标签
    private func contextSizeBadge(_ tokens: Int) -> some View {
        AppTag(ModelSelectorFormatService.contextSize(tokens))
    }

    /// 能力 badge
    private func capabilityBadge(title: String, systemImage: String) -> some View {
        AppTag(title, systemImage: systemImage)
            .help(title)
    }

    /// 供应商标签
    private func providerBadge(_ name: String) -> some View {
        AppTag(name)
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
            return LumiPluginLocalization.string("Available", bundle: .module)
        case .unavailable(let reason):
            return reason
        case .checking:
            return LumiPluginLocalization.string("Checking...", bundle: .module)
        case .unknown:
            return LumiPluginLocalization.string("Unknown", bundle: .module)
        }
    }

    /// TPS badge
    private func tpsBadge(_ tps: Double) -> some View {
        AppTag(ModelSelectorFormatService.tps(tps), systemImage: "speedometer")
    }

    /// 消息数量 badge
    private func sampleCountBadge(_ count: Int) -> some View {
        AppTag("\(count)", systemImage: "bubble.left.and.bubble.right")
    }

}
