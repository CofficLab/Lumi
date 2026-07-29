import LumiUI
import SwiftUI

// MARK: - About View

struct IdleTimeAboutView: View {
    @Environment(\.locale) private var locale
    @LumiTheme private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Feature Highlights
                FeatureHighlight(
                    icon: "moon.zzz.fill",
                    title: L("Idle Time Tracking"),
                    description: L("Monitor your computer idle time and inactivity patterns throughout the day")
                )

                FeatureHighlight(
                    icon: "chart.bar.fill",
                    title: L("Activity Visualization"),
                    description: L("View your activity patterns with visual heat strips showing when you're active or idle")
                )

                FeatureHighlight(
                    icon: "bell.badge.fill",
                    title: L("Idle Notifications"),
                    description: L("Receive notifications when you've been idle for a configurable duration")
                )

                FeatureHighlight(
                    icon: "clock.fill",
                    title: L("Session Analysis"),
                    description: L("Analyze your work sessions with detailed idle time statistics and trends")
                )

                // How It Works
                HowItWorksCard(
                    title: coreL("about.section.howItWorks"),
                    steps: [
                        L("Tracks keyboard and mouse activity continuously"),
                        L("Detects periods of user inactivity"),
                        L("Records idle time snapshots for analysis"),
                        L("Provides visual heat strips and notifications")
                    ]
                )

                // Use Cases
                UseCasesCard(
                    title: L("Use Cases"),
                    cases: [
                        ("Break Reminders", "Get notified to take breaks after focused work sessions"),
                        ("Productivity Tracking", "Understand your work patterns and peak hours"),
                        ("Background Scheduling", "Schedule background tasks during idle periods"),
                        ("Screen Timeout", "Configure automatic screen lock after extended idle")
                    ]
                )

                // Tips
                TipsCard(
                    title: coreL("about.section.tips"),
                    tips: [
                        L("Customize idle threshold in settings"),
                        L("Check the heat strip in the status bar for daily overview"),
                        L("Enable notifications to never miss a break reminder")
                    ]
                )
            }
            .padding()
        }
    }

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module, locale: locale)
    }

    private func coreL(_ key: String) -> String {
        switch key {
        case "about.section.howItWorks":
            return LumiPluginLocalization.string("How It Works", bundle: .module, locale: locale)
        case "about.section.tips":
            return LumiPluginLocalization.string("Tips", bundle: .module, locale: locale)
        default:
            return key
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

// MARK: - Use Cases Card

private struct UseCasesCard: View {
    @LumiTheme private var theme
    let title: String
    let cases: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(cases, id: \.0) { useCase in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.primary)
                            .frame(width: 16)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(useCase.0)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(theme.textPrimary)

                            Text(useCase.1)
                                .font(.system(size: 11))
                                .foregroundColor(theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()
                    }
                }
            }
        }
        .padding(14)
        .appSurface(style: .subtle, cornerRadius: 8)
    }
}

// MARK: - Tips Card

private struct TipsCard: View {
    @LumiTheme private var theme
    let title: String
    let tips: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.primary)
                            .frame(width: 16)

                        Text(tip)
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
