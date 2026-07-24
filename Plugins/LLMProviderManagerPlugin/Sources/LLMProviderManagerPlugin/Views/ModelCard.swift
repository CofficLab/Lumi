import LumiKernel
import LumiUI
import SwiftUI

public struct ModelCard: View {
    @LumiTheme private var theme
    @ObservedObject public var availability: ModelAvailabilityState
    @State private var presentedTransportFailure: LumiLLMFailureDetail?

    public let provider: LumiLLMProviderInfo
    public let model: String
    public let isSelected: Bool
    public let stat: ModelPerformanceStats?
    public let dailyUsage: ModelDailyTokenSeries?
    public let onSelect: (() -> Void)?

    public init(
        provider: LumiLLMProviderInfo,
        model: String,
        isSelected: Bool = false,
        stat: ModelPerformanceStats? = nil,
        dailyUsage: ModelDailyTokenSeries? = nil,
        availability: ModelAvailabilityState,
        onSelect: (() -> Void)? = nil
    ) {
        self.provider = provider
        self.model = model
        self.isSelected = isSelected
        self.stat = stat
        self.dailyUsage = dailyUsage
        self.availability = availability
        self.onSelect = onSelect
    }

    // MARK: - Derived

    private var modelDisplayName: String {
        provider.modelDisplayNames[model] ?? model
    }

    private var capabilities: LumiModelCapabilities? {
        provider.modelCapabilities[model]
    }

    private var checkState: ModelCheckState {
        availability.state(providerId: provider.id, modelId: model)
    }

    private var hasMetricBadges: Bool {
        (stat?.avgTPS ?? 0) > 0 || (stat?.sampleCount ?? 0) > 0
    }

    private var availabilityFailure: LumiLLMFailureDetail? {
        checkState.failure
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if let onSelect {
                AppListRow(isSelected: isSelected, action: onSelect) {
                    cardContent
                }
            } else {
                AppListRow {
                    cardContent
                }
            }
        }
        .popover(isPresented: transportDetailsPopoverBinding, arrowEdge: .bottom) {
            if let failure = presentedTransportFailure {
                AvailabilityTransportDetailsPopoverContent(failure: failure)
            }
        }
    }

    // MARK: - Card Content

    @ViewBuilder
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerRow

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

    // MARK: - Subviews

    @ViewBuilder
    private var headerRow: some View {
        HStack(spacing: 8) {
            availabilityStatusIcon(checkState)

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
    }

    @ViewBuilder
    private var capabilityBadges: some View {
        HStack(spacing: 6) {
            if let capabilities {
                capabilityBadge(
                    title: capabilities.supportsVision
                        ? LumiPluginLocalization.string("Image", bundle: .module)
                        : LumiPluginLocalization.string("Text", bundle: .module),
                    systemImage: capabilities.supportsVision ? "photo" : "text.bubble"
                )

                if capabilities.supportsTools {
                    capabilityBadge(
                        title: LumiPluginLocalization.string("Tools", bundle: .module),
                        systemImage: "wrench.and.screwdriver"
                    )
                }

                if capabilities.supportsTTS {
                    capabilityBadge(
                        title: LumiPluginLocalization.string("TTS", bundle: .module),
                        systemImage: "waveform"
                    )
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

    // MARK: - Helpers

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
    private func availabilityStatusIcon(_ state: ModelCheckState) -> some View {
        if state.phase == .checking {
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 12, height: 12)
        } else if state.isAvailable {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(.green)
        } else if let failure = state.failure {
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
}
