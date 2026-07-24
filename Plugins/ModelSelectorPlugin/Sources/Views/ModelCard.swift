import LLMProviderManagerPlugin
import LumiKernel
import LumiUI
import SwiftUI

/// 模型卡片，显示单个模型项及其可用性状态、选择状态和统计数据
struct ModelCard: View {
    @LumiTheme private var theme

    let provider: LumiLLMProviderInfo
    let model: String
    let isSelected: Bool
    let stat: ModelPerformanceStats?
    let dailyUsage: ModelDailyTokenSeries?
    let availability: ModelAvailabilityState
    let onSelect: () -> Void

    // MARK: - Derived

    private var modelDisplayName: String {
        provider.modelDisplayNames[model] ?? model
    }

    private var checkState: ModelCheckState {
        availability.state(providerId: provider.id, modelId: model)
    }

    private var isAvailable: Bool {
        checkState.isAvailable
    }

    private var isChecking: Bool {
        checkState.isChecking
    }

    private var failure: LumiLLMFailureDetail? {
        checkState.failure
    }

    private var hasStat: Bool {
        stat != nil && stat!.sampleCount > 0
    }

    private var hasDailyUsage: Bool {
        dailyUsage?.hasData ?? false
    }

    // MARK: - Body

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Selection indicator
                Circle()
                    .fill(selectionColor)
                    .frame(width: 8, height: 8)

                // Model info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(modelDisplayName)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(isSelected ? theme.primary : theme.textPrimary)
                            .lineLimit(1)

                        if isChecking {
                            ProgressView()
                                .scaleEffect(0.5)
                        } else if isAvailable {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                        } else if failure != nil {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                        }
                    }

                    // Model name subtext
                    if modelDisplayName != model {
                        Text(model)
                            .font(.system(size: 11))
                            .foregroundColor(theme.textTertiary)
                            .lineLimit(1)
                    }

                    // Stats row
                    if hasStat, let stat = stat {
                        HStack(spacing: 12) {
                            statItem(
                                icon: "arrow.up.arrowdown",
                                value: "\(stat.totalInputTokens + stat.totalOutputTokens) tokens",
                                label: nil
                            )

                            if stat.avgLatency > 0 {
                                statItem(
                                    icon: "clock",
                                    value: String(format: "%.1fs", stat.avgLatency / 1000),
                                    label: nil
                                )
                            }

                            if stat.avgTPS > 0 {
                                statItem(
                                    icon: "bolt.fill",
                                    value: String(format: "%.0f", stat.avgTPS),
                                    label: "tok/s"
                                )
                            }
                        }
                    }

                    // Error message
                    if let failure = failure {
                        Text(failure.availabilityDisplayText)
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Daily usage mini chart
                if hasDailyUsage, let usage = dailyUsage {
                    miniUsageChart(usage)
                }

                // Check mark for selected
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(theme.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Components

    @ViewBuilder
    private func statItem(icon: String, value: String, label: String?) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(theme.textTertiary)
            Text(value)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(theme.textSecondary)
            if let label = label {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(theme.textTertiary)
            }
        }
    }

    @ViewBuilder
    private func miniUsageChart(_ usage: ModelDailyTokenSeries) -> some View {
        let chartData = ModelDailyTokenBarChartMapper.chartData(from: usage)
        AppBarChart(data: chartData)
            .frame(width: 60, height: 24)
    }

    // MARK: - Styling

    private var selectionColor: Color {
        if isSelected {
            return theme.primary
        }
        return isAvailable ? .green : theme.textTertiary
    }

    private var cardBackground: Color {
        if isSelected {
            return theme.primary.opacity(0.08)
        }
        return theme.background.opacity(0.3)
    }
}
