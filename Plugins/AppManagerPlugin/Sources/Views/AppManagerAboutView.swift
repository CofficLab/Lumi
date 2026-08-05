import LumiUI
import SwiftUI

// MARK: - About View

struct AppManagerAboutView: View {
    @Environment(\.locale) private var locale
    @LumiTheme private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Feature Highlights
                FeatureHighlight(
                    icon: "square.grid.2x2",
                    title: L("Application Listing"),
                    description: L("Browse all installed macOS applications with detailed information")
                )

                FeatureHighlight(
                    icon: "info.circle",
                    title: L("App Details"),
                    description: L("View app size, version, and related files for each application")
                )

                FeatureHighlight(
                    icon: "trash",
                    title: L("Cache Management"),
                    description: L("Scan and clean application cache to free up disk space")
                )

                FeatureHighlight(
                    icon: "magnifyingglass",
                    title: L("Application Scanning"),
                    description: L("Automatically scan the system for installed applications")
                )

                // How It Works
                GlassInfoCard(
                    title: coreL("about.section.howItWorks"),
                    icon: "questionmark.circle",
                    iconColor: theme.primary
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.appMonoCaption)
                                    .foregroundStyle(theme.primary)
                                    .frame(width: 22, height: 22)
                                    .background(
                                        Circle()
                                            .fill(theme.primary.opacity(0.15))
                                    )

                                Text(step)
                                    .font(.appCaption)
                                    .foregroundColor(theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                // Tips
                AppCard(style: .subtle, cornerRadius: 12, padding: EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(coreL("about.section.tips"))
                            .font(.appBodyEmphasized)
                            .foregroundColor(theme.textPrimary)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(tips, id: \.self) { tip in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(theme.primary)
                                        .frame(width: 16)

                                    Text(tip)
                                        .font(.appCaption)
                                        .foregroundColor(theme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var steps: [String] {
        [
            L("Scans system Applications folder and other locations"),
            L("Builds a comprehensive list of installed apps"),
            L("Calculates app size and related cache files"),
            L("Provides options to clean app cache")
        ]
    }

    private var tips: [String] {
        [
            L("Click on an app to view detailed information"),
            L("Use the cache manager to free up disk space"),
            L("Rescan to refresh the application list")
        ]
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
        AppCard(style: .subtle, cornerRadius: 12, padding: EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)) {
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
                        .font(.appBodyEmphasized)
                        .foregroundColor(theme.textPrimary)

                    Text(description)
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
    }
}
