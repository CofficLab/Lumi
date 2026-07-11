
import LumiChatKit
import LumiCoreKit
import LumiUI
import SwiftUI

/// 供应商摘要卡片，显示在模型列表顶部，展示模型统计信息、刷新操作和状态消息
struct ProviderSummaryCard: View {
    @LumiTheme private var theme
    @ObservedObject var availability: ModelAvailabilityState

    let provider: LumiLLMProviderInfo
    let isChecking: Bool
    let onRefresh: () -> Void
    let statusMessage: String?
    let statusMessageColor: Color?
    var dailyUsage: [String: ModelDailyTokenSeries] = [:]

    /// 用于内联配置 API Key 的供应商实例（可选）。
    var providerInstance: (any LumiLLMProvider)? = nil
    /// 保存 API Key 后触发的回调（用于可用性重检）。
    var onAPIKeySaved: (() -> Void)? = nil

    /// 用户主动触发的 "重配" 编辑状态。
    @State private var isAPIKeyEditing: Bool = false

    // MARK: - Derived

    private var totalModelCount: Int {
        provider.availableModels.count
    }

    private var availableModelCount: Int {
        availability.availableCount(for: provider)
    }

    private var isProviderAvailable: Bool {
        availableModelCount > 0
    }

    private var unavailableCount: Int {
        totalModelCount - availableModelCount
    }

    private var providerDailyUsage: [String: ModelDailyTokenSeries] {
        dailyUsage.filter { $0.value.providerID == provider.id }
    }

    private var hasDailyUsage: Bool {
        !providerDailyUsage.isEmpty && providerDailyUsage.values.contains { $0.hasData }
    }

    /// 当前是否处于「未配置 API Key」状态。
    private var isMissingAPIKey: Bool {
        guard let instance = providerInstance else { return false }
        if provider.isLocal { return false }
        return !instance.hasApiKey()
    }

    /// 当前是否处于「已配置 API Key，但模型检测失败」状态。
    private var hasCheckedAndFailed: Bool {
        guard let instance = providerInstance else { return false }
        if provider.isLocal { return false }
        guard instance.hasApiKey() else { return false }
        guard let failure = availability.firstReconfigurableFailure(for: provider) else { return false }
        return !failure.availabilityDisplayText.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Icon with availability indicator
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconBackgroundColor)
                        .frame(width: 36, height: 36)
                    Image(systemName: provider.isLocal ? "cpu" : "cloud")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(iconColor)
                    Circle()
                        .fill(isProviderAvailable ? .green : .red)
                        .frame(width: 10, height: 10)
                        .offset(x: 10, y: 10)
                }

                // Provider info
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                }

                Spacer()

                // Refresh button and status badge
                HStack(spacing: 12) {
                    if isChecking {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Button {
                            onRefresh()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .help("Re-check availability")
                    }

                    statusBadge
                }
            }

            if isMissingAPIKey, let instance = providerInstance {
                ProviderAPIKeyInputView(
                    provider: provider,
                    providerInstance: instance,
                    onSaved: { onAPIKeySaved?() }
                )
            } else if hasCheckedAndFailed, let instance = providerInstance {
                checkedFailedBlock(instance: instance)
            } else if let message = statusMessage, let color = statusMessageColor {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                    .lineLimit(2)
            }

            // 14-day usage statistics chart
            if hasDailyUsage {
                Divider()
                    .background(theme.divider)
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 6) {
                    AppBarChart(
                        data: ModelDailyTokenBarChartMapper.chartData(from: providerDailyUsage)
                    )
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.divider, lineWidth: 0.5)
                )
            }
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Components

    @ViewBuilder
    private func checkedFailedBlock(instance: any LumiLLMProvider) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.red)
                    .padding(.top, 1)

                Text(
                    verbatim: availability.firstReconfigurableFailure(for: provider)?.availabilityDisplayText ?? ""
                )
                .font(.system(size: 11))
                .foregroundColor(.red)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

                if !isAPIKeyEditing {
                    Button {
                        isAPIKeyEditing = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 10, weight: .medium))
                            Text(
                                verbatim: LumiPluginLocalization.string(
                                    "Reconfigure",
                                    bundle: .module
                                )
                            )
                            .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(theme.primary)
                    }
                    .buttonStyle(.plain)
                    .help(
                        LumiPluginLocalization.string(
                            "Reconfigure API Key",
                            bundle: .module
                        )
                    )
                }
            }

            if isAPIKeyEditing {
                ProviderAPIKeyInputView(
                    provider: provider,
                    providerInstance: instance,
                    onSaved: {
                        isAPIKeyEditing = false
                        onAPIKeySaved?()
                    },
                    onCancel: { isAPIKeyEditing = false }
                )
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isProviderAvailable {
            HStack(spacing: 4) {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
                Text(verbatim: "\(availableModelCount)/\(totalModelCount)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(.green.opacity(0.1))
            )
        } else {
            HStack(spacing: 4) {
                Circle()
                    .fill(theme.textTertiary)
                    .frame(width: 6, height: 6)
                Text("不可用")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.textTertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(theme.textTertiary.opacity(0.1))
            )
        }
    }

    // MARK: - Styling

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(theme.background.opacity(0.5))
    }

    private var iconBackgroundColor: Color {
        isProviderAvailable ? .green.opacity(0.15) : theme.textTertiary.opacity(0.15)
    }

    private var iconColor: Color {
        isProviderAvailable ? .green : theme.textSecondary
    }
}
