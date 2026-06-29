import LumiCoreKit
import LumiUI
import SwiftUI

/// Selectable model row for LLM provider settings.
struct ModelSettingsRow: View {
    @LumiTheme private var theme

    let model: String
    let isDefault: Bool
    let defaultLabel: String
    let supportsVision: Bool?
    let supportsTools: Bool?
    let supportsTTS: Bool?
    let stat: ModelPerformanceStats?
    let dailyUsage: ModelDailyTokenSeries?
    let onTap: (() -> Void)?

    init(
        model: String,
        isDefault: Bool,
        defaultLabel: String = "默认",
        supportsVision: Bool? = nil,
        supportsTools: Bool? = nil,
        supportsTTS: Bool? = nil,
        stat: ModelPerformanceStats? = nil,
        dailyUsage: ModelDailyTokenSeries? = nil,
        onTap: @escaping () -> Void
    ) {
        self.model = model
        self.isDefault = isDefault
        self.defaultLabel = defaultLabel
        self.supportsVision = supportsVision
        self.supportsTools = supportsTools
        self.supportsTTS = supportsTTS
        self.stat = stat
        self.dailyUsage = dailyUsage
        self.onTap = onTap
    }

    /// Read-only display without default-model selection.
    init(
        model: String,
        supportsVision: Bool? = nil,
        supportsTools: Bool? = nil,
        supportsTTS: Bool? = nil,
        stat: ModelPerformanceStats? = nil,
        dailyUsage: ModelDailyTokenSeries? = nil
    ) {
        self.model = model
        self.isDefault = false
        self.defaultLabel = "默认"
        self.supportsVision = supportsVision
        self.supportsTools = supportsTools
        self.supportsTTS = supportsTTS
        self.stat = stat
        self.dailyUsage = dailyUsage
        self.onTap = nil
    }

    var body: some View {
        Group {
            if let onTap {
                AppListRow(isSelected: isDefault, action: onTap) {
                    rowContent
                }
            } else {
                AppListRow {
                    rowContent
                }
            }
        }
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text(model)
                    .font(.appBody)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if isDefault {
                    AppTag(defaultLabel, style: .accent)
                }
            }

            if hasCapabilities {
                HStack(spacing: 6) {
                    if let supportsVision {
                        capabilityBadge(
                            title: supportsVision ? "Image" : "Text",
                            systemImage: supportsVision ? "photo" : "text.bubble"
                        )
                    }
                    if let supportsTools, supportsTools {
                        capabilityBadge(title: "Tools", systemImage: "wrench.and.screwdriver")
                    }
                    if let supportsTTS, supportsTTS {
                        capabilityBadge(title: "TTS", systemImage: "waveform")
                    }
                    Spacer(minLength: 0)
                }
            }

            if hasMetricBadges {
                HStack(spacing: 6) {
                    if let stat, stat.avgTPS > 0 {
                        AppTag(TokenCountFormat.tps(stat.avgTPS), systemImage: "speedometer")
                    }
                    if let stat, stat.sampleCount > 0 {
                        AppTag("\(stat.sampleCount)", systemImage: "bubble.left.and.bubble.right")
                    }
                    Spacer(minLength: 0)
                }
            }

            if let dailyUsage, dailyUsage.hasData {
                AppBarChart(data: ModelDailyTokenBarChartMapper.chartData(from: dailyUsage))
            }
        }
    }

    private var hasCapabilities: Bool {
        supportsVision != nil || (supportsTools == true) || (supportsTTS == true)
    }

    private var hasMetricBadges: Bool {
        (stat?.avgTPS ?? 0) > 0 || (stat?.sampleCount ?? 0) > 0
    }

    @ViewBuilder
    private func capabilityBadge(title: String, systemImage: String) -> some View {
        AppTag(title, systemImage: systemImage, style: .subtle)
            .help(title)
    }
}
