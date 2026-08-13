import LumiUI
import KernelLumi
import SwiftUI

// MARK: - About View

/// Plugin about view for Activity Heatmap.
/// Introduces the plugin's heatmap and token tracking capabilities.
struct ActivityHeatmapAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Feature Highlights
                FeatureHighlight(
                    icon: "chart.bar.xaxis",
                    title: LumiPluginLocalization.string("Activity Heatmap", bundle: .module),
                    description: LumiPluginLocalization.string("Visualize your conversation activity with a GitHub-style calendar heatmap. Color intensity reflects daily message volume.", bundle: .module)
                )

                FeatureHighlight(
                    icon: "arrow.up.right.line",
                    title: LumiPluginLocalization.string("Token Consumption Tracking", bundle: .module),
                    description: LumiPluginLocalization.string("Monitor daily token usage through an interactive line chart. Identify high-usage days and optimize your prompts.", bundle: .module)
                )

                FeatureHighlight(
                    icon: "chart.pie.fill",
                    title: LumiPluginLocalization.string("Statistics Dashboard", bundle: .module),
                    description: LumiPluginLocalization.string("Get instant insights: total messages, active days, current/longest streaks, weekday distribution, and peak activity days.", bundle: .module)
                )

                FeatureHighlight(
                    icon: "cylinder.split.1x2.fill",
                    title: LumiPluginLocalization.string("Efficient Caching", bundle: .module),
                    description: LumiPluginLocalization.string("Historical data is cached locally for instant loading. Today's activity is always fetched in real-time for accuracy.", bundle: .module)
                )

                // How It Works
                HowItWorksCard(
                    title: LumiPluginLocalization.string("How It Works", bundle: .module),
                    steps: [
                        LumiPluginLocalization.string("Tracks every message sent through Lumi conversations", bundle: .module),
                        LumiPluginLocalization.string("Aggregates daily message counts and token usage", bundle: .module),
                        LumiPluginLocalization.string("Caches historical data for fast subsequent loads", bundle: .module),
                        LumiPluginLocalization.string("Displays data in interactive heatmap and line chart", bundle: .module)
                    ]
                )

                // Requirements
                RequirementsCard(
                    title: LumiPluginLocalization.string("Requirements", bundle: .module),
                    items: [
                        LumiPluginLocalization.string("macOS 14.0 or later", bundle: .module),
                        LumiPluginLocalization.string("Swift 6.0 or later", bundle: .module),
                        LumiPluginLocalization.string("KernelLumi with MessageManaging service", bundle: .module),
                    ]
                )

                // Data Privacy Note
                DataPrivacyCard()
            }
            .padding()
        }
    }
}

// MARK: - Feature Highlight

private struct FeatureHighlight: View {
    @LumiTheme private var theme
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(theme.primary)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(theme.primary.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textPrimary)

                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .appSurface(style: .subtle, cornerRadius: 8)
    }
}

// MARK: - How It Works Card

private struct HowItWorksCard: View {
    @LumiTheme private var theme
    let title: String
    let steps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.primary)
                            .frame(width: 22, height: 22)
                            .background(
                                Circle()
                                    .fill(theme.primary.opacity(0.15))
                            )

                        Text(step)
                            .font(.system(size: 13))
                            .foregroundColor(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(14)
        .appSurface(style: .subtle, cornerRadius: 8)
    }
}

// MARK: - Requirements Card

private struct RequirementsCard: View {
    @LumiTheme private var theme
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.success)
                            .frame(width: 16)

                        Text(item)
                            .font(.system(size: 13))
                            .foregroundColor(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(14)
        .appSurface(style: .subtle, cornerRadius: 8)
    }
}

// MARK: - Data Privacy Card

private struct DataPrivacyCard: View {
    @LumiTheme private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 18))
                .foregroundStyle(theme.primary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(theme.primary.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(LumiPluginLocalization.string("Data Privacy", bundle: .module))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textPrimary)

                Text(LumiPluginLocalization.string("All activity data is stored locally on your device. No data is sent to external servers.", bundle: .module))
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .appSurface(style: .subtle, cornerRadius: 8)
    }
}

#Preview {
    ActivityHeatmapAboutView()
        .frame(width: 400, height: 600)
}
