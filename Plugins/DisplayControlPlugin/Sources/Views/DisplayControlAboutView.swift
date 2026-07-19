import LumiUI
import SwiftUI

// MARK: - About View

struct DisplayControlAboutView: View {
    @Environment(\.locale) private var locale
    @LumiTheme private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Feature Highlights
                FeatureHighlight(
                    icon: "sun.max.fill",
                    title: L("Brightness Control"),
                    description: L("Adjust brightness for external displays via DDC/CI protocol")
                )

                FeatureHighlight(
                    icon: "speaker.wave.2.fill",
                    title: L("Volume Control"),
                    description: L("Control audio volume directly from your menu bar")
                )

                FeatureHighlight(
                    icon: "circle.lefthalf.filled",
                    title: L("Contrast Adjustment"),
                    description: L("Fine-tune display contrast for optimal viewing")
                )

                FeatureHighlight(
                    icon: "display",
                    title: L("Multi-Display Support"),
                    description: L("Manage multiple displays with individual controls")
                )

                // How It Works
                HowItWorksCard(
                    title: coreL("about.section.howItWorks"),
                    steps: [
                        L("Detects connected displays with DDC/CI support"),
                        L("Provides brightness, volume, and contrast sliders"),
                        L("Updates display settings in real-time"),
                        L("Stores preferences for each display")
                    ]
                )

                // Requirements
                RequirementsCard(
                    title: L("Requirements"),
                    items: [
                        L("macOS 14.0 or later"),
                        L("External displays with DDC/CI support"),
                        L("USB-C or DisplayPort connection (recommended)")
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
        case "about.section.howItWorks": return LumiPluginLocalization.string("How It Works", bundle: .module, locale: locale)
        case "about.section.tips": return LumiPluginLocalization.string("Tips", bundle: .module, locale: locale)
        default: return key
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
