import LLMAvailabilityPlugin
import LumiCoreKit
import LumiUI
import SwiftUI

struct ModelRow: View {
    @LumiTheme private var theme
    @ObservedObject private var availabilityStore = LLMAvailabilityStore.shared
    @State private var presentedTransportFailure: LumiLLMFailureDetail?

    let provider: LumiLLMProviderInfo
    let model: String
    let isSelected: Bool
    let stat: ModelPerformanceStats?
    let dailyUsage: ModelDailyTokenSeries?
    let onSelect: () -> Void

    init(
        provider: LumiLLMProviderInfo,
        model: String,
        isSelected: Bool,
        stat: ModelPerformanceStats? = nil,
        dailyUsage: ModelDailyTokenSeries? = nil,
        onSelect: @escaping () -> Void
    ) {
        self.provider = provider
        self.model = model
        self.isSelected = isSelected
        self.stat = stat
        self.dailyUsage = dailyUsage
        self.onSelect = onSelect
    }

    // MARK: - Derived

    private var modelDisplayName: String {
        provider.modelDisplayNames[model] ?? model
    }

    private var capabilities: LumiModelCapabilities? {
        provider.modelCapabilities[model]
    }

    private var availabilityStatus: LLMAvailabilityStatus {
        availabilityStore.status(providerId: provider.id, modelId: model) ?? .unknown
    }

    private var hasMetricBadges: Bool {
        (stat?.avgTPS ?? 0) > 0 || (stat?.sampleCount ?? 0) > 0
    }

    private var availabilityFailure: LumiLLMFailureDetail? {
        if case .unavailable(let failure) = availabilityStatus {
            return failure
        }
        return nil
    }

    var body: some View {
        AppListRow(isSelected: isSelected, action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    availabilityStatusIcon(availabilityStatus)

                    Text(modelDisplayName)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.primary)
                    }

                    Spacer(minLength: 0)
                }

                if let availabilityFailure {
                    availabilityErrorBlock(availabilityFailure) {
                        presentedTransportFailure = availabilityFailure
                    }
                }

                capabilityBadges

                if hasMetricBadges {
                    metricBadges
                }

                if let dailyUsage, dailyUsage.hasData {
                    AppBarChart(data: ModelDailyTokenBarChartMapper.chartData(from: dailyUsage))
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
        }
        .popover(isPresented: transportDetailsPopoverBinding, arrowEdge: .bottom) {
            if let failure = presentedTransportFailure {
                AvailabilityTransportDetailsPopoverContent(failure: failure)
            }
        }
    }

    private var transportDetailsPopoverBinding: Binding<Bool> {
        Binding(
            get: { presentedTransportFailure != nil },
            set: { isPresented in
                if !isPresented {
                    presentedTransportFailure = nil
                }
            }
        )
    }

    @ViewBuilder
    private var capabilityBadges: some View {
        HStack(spacing: 6) {
            if let capabilities {
                capabilityBadge(
                    title: capabilities.supportsVision ? "Image" : "Text",
                    systemImage: capabilities.supportsVision ? "photo" : "text.bubble"
                )

                if capabilities.supportsTools {
                    capabilityBadge(title: "Tools", systemImage: "wrench.and.screwdriver")
                }

                if capabilities.supportsTTS {
                    capabilityBadge(title: "TTS", systemImage: "waveform")
                }
            } else {
                AppTag(provider.displayName)
                AppTag(provider.id, systemImage: "cloud")
            }

            if let contextSize = provider.contextWindowSizes[model] {
                AppTag(ModelSelectorFormatService.contextSize(contextSize), systemImage: "text.viewfinder")
            }
        }
    }

    @ViewBuilder
    private var metricBadges: some View {
        HStack(spacing: 6) {
            if let stat, stat.avgTPS > 0 {
                AppTag(ModelSelectorFormatService.tps(stat.avgTPS), systemImage: "speedometer")
            }

            if let stat, stat.sampleCount > 0 {
                AppTag("\(stat.sampleCount)", systemImage: "bubble.left.and.bubble.right")
            }
        }
    }

    // MARK: - Helper

    @ViewBuilder
    private func capabilityBadge(title: String, systemImage: String) -> some View {
        AppTag(title, systemImage: systemImage, style: .subtle)
            .help(title)
    }

    @ViewBuilder
    private func availabilityErrorBlock(
        _ failure: LumiLLMFailureDetail,
        onShowTransportDetails: @escaping () -> Void
    ) -> some View {
        let message = failure.availabilityDisplayText
        let isUnsupported = failure.reason == .unsupportedModel
        if !message.isEmpty {
            HStack(alignment: .top, spacing: 6) {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(isUnsupported ? theme.textSecondary : .red)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if failure.hasTransportDiagnostics {
                    AvailabilityTransportDetailsTrigger(action: onShowTransportDetails)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                (isUnsupported ? theme.textTertiary.opacity(0.12) : Color.red.opacity(0.08)),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
        }
    }

    @ViewBuilder
    private func availabilityStatusIcon(_ status: LLMAvailabilityStatus) -> some View {
        switch status {
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(.green)
        case .checking:
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 12, height: 12)
        case .unavailable(let failure):
            if failure.reason == .unsupportedModel {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }
        case .unknown:
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}
