import Foundation
import LumiKernel
import LumiUI
import SwiftUI

/// 设置页面中的模型行视图
///
/// 显示模型名称、可用性状态、性能统计和每日用量图表（不可点击选择）。
struct ProviderModelRow: View {
    @LumiTheme private var theme

    let provider: LumiLLMProviderInfo
    let model: String
    let stat: ModelPerformanceStats?
    let dailyUsage: ModelDailyTokenSeries?
    let availability: ModelAvailabilityState

    private var modelDisplayName: String {
        provider.modelInfo(for: model)?.displayName ?? model
    }

    private var checkState: ModelCheckState {
        availability.state(providerId: provider.id, modelId: model)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerRow

            if let failure = checkState.failure, !failure.availabilityDisplayText.isEmpty {
                errorBlock(failure)
            }

            capabilityBadges

            if let stat, stat.avgTPS > 0 || stat.sampleCount > 0 {
                metricBadges(stat)
            }

            if let dailyUsage, dailyUsage.hasData {
                VStack(alignment: .leading, spacing: 6) {
                    AppBarChart(data: ModelDailyTokenBarChartMapper.chartData(from: dailyUsage))
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
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            availabilityIcon

            Text(modelDisplayName)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var availabilityIcon: some View {
        if checkState.isChecking {
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 12, height: 12)
        } else if checkState.isAvailable {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(.green)
        } else if let failure = checkState.failure {
            if failure.reason == .unsupportedModel {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }
        } else {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var capabilityBadges: some View {
        if let capabilities = provider.modelInfo(for: model)?.capabilities {
            HStack(spacing: 6) {
                AppTag(
                    capabilities.supportsVision
                        ? LumiPluginLocalization.string("Image")
                        : LumiPluginLocalization.string("Text"),
                    systemImage: capabilities.supportsVision ? "photo" : "text.bubble",
                    style: .subtle
                )
                if capabilities.supportsTools {
                    AppTag(
                        LumiPluginLocalization.string("Tools"),
                        systemImage: "wrench.and.screwdriver",
                        style: .subtle
                    )
                }
                if capabilities.supportsTTS {
                    AppTag(
                        LumiPluginLocalization.string("TTS"),
                        systemImage: "waveform",
                        style: .subtle
                    )
                }
            }
        } else {
            HStack(spacing: 6) {
                AppTag(provider.displayName)
                AppTag(provider.id, systemImage: "cloud")
            }
        }

        if let contextSize = provider.modelInfo(for: model)?.contextWindowSize {
            HStack(spacing: 6) {
                Spacer(minLength: 0)
                AppTag(ModelSelectorFormatService.contextSize(contextSize), systemImage: "text.viewfinder")
            }
        }
    }

    @ViewBuilder
    private func metricBadges(_ stat: ModelPerformanceStats) -> some View {
        HStack(spacing: 6) {
            if stat.avgTPS > 0 {
                AppTag(ModelSelectorFormatService.tps(stat.avgTPS), systemImage: "speedometer")
            }
            if stat.sampleCount > 0 {
                AppTag("\(stat.sampleCount)", systemImage: "bubble.left.and.bubble.right")
            }
        }
    }

    @ViewBuilder
    private func errorBlock(_ failure: LumiLLMFailureDetail) -> some View {
        let message = failure.availabilityDisplayText
        let isUnsupported = failure.reason == .unsupportedModel
        if !message.isEmpty {
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(isUnsupported ? theme.textSecondary : .red)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    (isUnsupported ? theme.textTertiary.opacity(0.12) : Color.red.opacity(0.08)),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
        }
    }
}
