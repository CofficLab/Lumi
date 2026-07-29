import LumiUI
import LumiKernel
import SwiftUI

// MARK: - About View

/// Plugin about view for Brew Manager.
/// Introduces the plugin's Homebrew package management capabilities.
struct BrewManagerAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Feature Highlights
                FeatureHighlight(
                    icon: "list.bullet.rectangle.fill",
                    title: LumiPluginLocalization.string("Installed Packages", bundle: .module),
                    description: LumiPluginLocalization.string("Browse all installed Homebrew formulae and casks. View package details including version, installation date, and dependencies.", bundle: .module)
                )

                FeatureHighlight(
                    icon: "arrow.up.circle.fill",
                    title: LumiPluginLocalization.string("Update Checker", bundle: .module),
                    description: LumiPluginLocalization.string("Identify packages with available updates. See current vs. latest version at a glance to plan your upgrade strategy.", bundle: .module)
                )

                FeatureHighlight(
                    icon: "magnifyingglass",
                    title: LumiPluginLocalization.string("Package Search", bundle: .module),
                    description: LumiPluginLocalization.string("Search Homebrew repository for new packages. Browse descriptions, homepages, and installation instructions.", bundle: .module)
                )

                FeatureHighlight(
                    icon: "arrow.down.circle.fill",
                    title: LumiPluginLocalization.string("Install & Uninstall", bundle: .module),
                    description: LumiPluginLocalization.string("Install new packages or uninstall existing ones. Monitor installation progress and handle errors gracefully.", bundle: .module)
                )

                FeatureHighlight(
                    icon: "arrow.clockwise.circle.fill",
                    title: LumiPluginLocalization.string("Batch Upgrade", bundle: .module),
                    description: LumiPluginLocalization.string("Upgrade all outdated packages at once, or selectively upgrade individual packages. Keep your system fresh.", bundle: .module)
                )

                FeatureHighlight(
                    icon: "checkmark.shield.fill",
                    title: LumiPluginLocalization.string("Environment Check", bundle: .module),
                    description: LumiPluginLocalization.string("Automatically detects Homebrew installation status. Shows clear guidance when Homebrew is not installed.", bundle: .module)
                )

                // Package Types
                PackageTypesCard(
                    title: LumiPluginLocalization.string("Supported Package Types", bundle: .module),
                    types: [
                        ("Formulae", "Command-line tools and libraries"),
                        ("Casks", "macOS GUI applications"),
                        ("Fonts", "System fonts"),
                        ("Services", "Background services")
                    ]
                )

                // Quick Actions
                QuickActionsCard(
                    title: LumiPluginLocalization.string("Quick Actions", bundle: .module),
                    actions: [
                        ("Install", "Download and install a package"),
                        ("Uninstall", "Remove a package from your system"),
                        ("Upgrade", "Update to the latest version"),
                        ("Upgrade All", "Update all outdated packages"),
                        ("Search", "Find packages in Homebrew"),
                        ("Info", "View package details and dependencies")
                    ]
                )

                // Requirements
                RequirementsCard(
                    title: LumiPluginLocalization.string("Requirements", bundle: .module),
                    items: [
                        "macOS 14.0 or later",
                        "Swift 6.0 or later",
                        "Homebrew installed (/opt/homebrew)"
                    ]
                )
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

// MARK: - Package Types Card

private struct PackageTypesCard: View {
    @LumiTheme private var theme
    let title: String
    let types: [(String, String)]

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(types, id: \.0) { type in
                    HStack(spacing: 10) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(theme.primary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.0)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(theme.textPrimary)

                            Text(type.1)
                                .font(.system(size: 10))
                                .foregroundColor(theme.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer()
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(theme.overlay)
                    )
                }
            }
        }
        .padding(14)
        .appSurface(style: .subtle, cornerRadius: 8)
    }
}

// MARK: - Quick Actions Card

private struct QuickActionsCard: View {
    @LumiTheme private var theme
    let title: String
    let actions: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(actions, id: \.0) { action in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.primary)
                            .frame(width: 16)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.0)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(theme.textPrimary)

                            Text(action.1)
                                .font(.system(size: 11))
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
    BrewManagerAboutView()
        .frame(width: 400, height: 800)
}
