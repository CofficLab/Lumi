import LumiUI
import SwiftUI
import LumiKernel

/// 防休眠插件关于视图 - 展示插件的功能介绍和说明
struct CaffeinateAboutView: View {
    @Environment(\.locale) private var locale
    @LumiTheme private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Feature Highlights
                FeatureHighlight(
                    icon: "bolt.fill",
                    title: L("Prevent System Sleep"),
                    description: L("Keep your Mac awake during long-running tasks like downloads or renders")
                )

                FeatureHighlight(
                    icon: "timer",
                    title: L("Timer Mode"),
                    description: L("Set a specific duration to prevent sleep, then automatically deactivate")
                )

                FeatureHighlight(
                    icon: "moon.zzz",
                    title: L("Display Control"),
                    description: L("Optionally turn off display while keeping system awake to save power")
                )

                FeatureHighlight(
                    icon: "menubar.rectangle",
                    title: L("Menu Bar Integration"),
                    description: L("Quick access to activate/deactivate from the menu bar")
                )

                // How It Works
                HowItWorksCard(
                    title: coreL("about.section.howItWorks"),
                    steps: [
                        L("Uses IOKit power assertions to prevent system sleep"),
                        L("Supports both indefinite and timed activation modes"),
                        L("Can optionally turn off display while system stays awake"),
                        L("Provides status indicator in menu bar for quick control")
                    ]
                )

                // Features
                FeaturesCard(
                    title: L("Key Features"),
                    items: [
                        L("Indefinite mode: Keep system awake until manually deactivated"),
                        L("Timed mode: Set duration from minutes to hours"),
                        L("Display-off mode: Save power while system runs"),
                        L("Agent tools for automated workflows"),
                        L("Real-time status monitoring and elapsed time display")
                    ]
                )

                // Use Cases
                UseCasesCard(
                    title: L("Common Use Cases"),
                    cases: [
                        (icon: "arrow.down.circle", title: L("Downloads"), desc: L("Prevent sleep during large file downloads")),
                        (icon: "video.fill", title: L("Video Processing"), desc: L("Keep system awake during encoding or rendering")),
                        (icon: "server.rack", title: L("Server Tasks"), desc: L("Run background services without interruption")),
                        (icon: "clock", title: L("Presentations"), desc: L("Prevent display sleep during presentations"))
                    ]
                )

                // Requirements
                RequirementsCard(
                    title: L("Requirements"),
                    items: [
                        L("macOS 14.0 or later"),
                        L("System permission for power management"),
                        L("No additional configuration required")
                    ]
                )
            }
            .padding()
        }
    }

    private func L(_ key: String) -> String {
        PluginCaffeinateLocalization.string(key)
    }

    private func coreL(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: LumiKernelResources.bundle, locale: locale)
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

// MARK: - Features Card

private struct FeaturesCard: View {
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

// MARK: - Use Cases Card

private struct UseCasesCard: View {
    @LumiTheme private var theme
    let title: String
    let cases: [(icon: String, title: String, desc: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(cases, id: \.title) { useCase in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: useCase.icon)
                            .font(.system(size: 16))
                            .foregroundStyle(theme.info)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(useCase.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(theme.textPrimary)
                            Text(useCase.desc)
                                .font(.system(size: 12))
                                .foregroundColor(theme.textSecondary)
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

#Preview {
    CaffeinateAboutView()
        .frame(width: 500, height: 700)
}
