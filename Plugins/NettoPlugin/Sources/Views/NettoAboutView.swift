import LumiUI
import SwiftUI

// MARK: - About View

struct NettoAboutView: View {
    @Environment(\.locale) private var locale
    @LumiTheme private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Feature Highlights
                FeatureHighlight(
                    icon: "shield.lefthalf.filled",
                    title: L("Network Permission Management"),
                    description: L("Control which applications can access the network")
                )

                FeatureHighlight(
                    icon: "app.badge",
                    title: L("App-Level Control"),
                    description: L("Set network permissions for individual applications")
                )

                FeatureHighlight(
                    icon: "arrow.up.arrow.down",
                    title: L("Traffic Monitoring"),
                    description: L("Monitor network traffic and connection attempts")
                )

                FeatureHighlight(
                    icon: "lock.rotation",
                    title: L("Rule Profiles"),
                    description: L("Create and switch between different firewall rule profiles")
                )

                // How It Works
                HowItWorksCard(
                    title: coreL("about.section.howItWorks"),
                    steps: [
                        L("Monitors network connection requests from applications"),
                        L("Applies rules based on your configuration"),
                        L("Blocks or allows traffic according to permissions"),
                        L("Logs network activity for review")
                    ]
                )

                // Tips
                TipsCard(
                    title: coreL("about.section.tips"),
                    tips: [
                        L("Start with a permissive profile and tighten rules gradually"),
                        L("Review logs to identify unnecessary network access"),
                        L("Use profiles for different network environments")
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
        // Fallback for core localization keys
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
