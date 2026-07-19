import LumiKernel
import LumiUI
import SwiftUI

// MARK: - About View

struct HostsManagerAboutView: View {
    @Environment(\.locale) private var locale
    @LumiTheme private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Feature Highlights
                FeatureHighlight(
                    icon: "list.bullet.rectangle",
                    title: L("Hosts File Management"),
                    description: L("Edit and manage the system hosts file with a user-friendly interface")
                )

                FeatureHighlight(
                    icon: "square.and.arrow.down.on.square",
                    title: L("Profile Support"),
                    description: L("Create and switch between different hosts profiles")
                )

                FeatureHighlight(
                    icon: "arrow.triangle.2.circlepath",
                    title: L("Quick Toggle"),
                    description: L("Enable or disable hosts entries without deleting them")
                )

                FeatureHighlight(
                    icon: "doc.text.magnifyingglass",
                    title: L("Syntax Highlighting"),
                    description: L("Syntax highlighting and validation for hosts entries")
                )

                // How It Works
                HowItWorksCard(
                    title: coreL("about.section.howItWorks"),
                    steps: [
                        L("Reads the system hosts file with proper permissions"),
                        L("Parses and displays entries in an organized list"),
                        L("Allows adding, editing, and removing entries"),
                        L("Writes changes back to the hosts file")
                    ]
                )

                // Tips
                TipsCard(
                    title: coreL("about.section.tips"),
                    tips: [
                        L("Backup your hosts file before making changes"),
                        L("Use profiles to switch between different configurations"),
                        L("Comments start with # and are ignored")
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
        case "about.section.howItWorks": return L("How It Works")
        case "about.section.tips": return L("Tips")
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
