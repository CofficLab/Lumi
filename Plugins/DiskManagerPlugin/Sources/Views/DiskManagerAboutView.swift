import LumiUI
import LumiKernel
import SwiftUI

// MARK: - About View

/// Plugin about view for Disk Manager.
/// Introduces the plugin's disk analysis and cleanup capabilities.
struct DiskManagerAboutView: View {
    @Environment(\.locale) private var locale
    @LumiTheme private var theme

    private func L(_ key: String) -> String {
        PluginDiskManagerLocalization.string(key, locale: locale)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Feature Highlights
                FeatureHighlight(
                    icon: "chart.pie.fill",
                    title: L("Disk Usage Overview"),
                    description: L("View total, used, and available disk space at a glance. Monitor storage health and identify space consumption patterns.")
                )

                FeatureHighlight(
                    icon: "doc.fill",
                    title: L("Large File Scanner"),
                    description: L("Discover large files consuming your disk space. Scan any directory to find files sorted by size for easy cleanup.")
                )

                FeatureHighlight(
                    icon: "folder.fill",
                    title: L("Directory Analysis"),
                    description: L("Visualize directory size breakdowns with interactive tree views. Identify which folders are taking up the most space.")
                )

                FeatureHighlight(
                    icon: "trash.fill",
                    title: L("Cache Cleanup"),
                    description: L("Clean up system caches to free up disk space. Safely remove temporary files without affecting system stability.")
                )

                FeatureHighlight(
                    icon: "hammer.fill",
                    title: L("Xcode Cleanup"),
                    description: L("Free up significant space by removing Xcode-derived data, old simulators, build products, and archives.")
                )

                FeatureHighlight(
                    icon: "folder.badge.gearshape",
                    title: L("Project Cleanup"),
                    description: L("Scan project directories for removable build artifacts like DerivedData, build folders, and CocoaPods caches.")
                )

                FeatureHighlight(
                    icon: "magnifyingglass",
                    title: L("Finder Integration"),
                    description: L("Quickly reveal scanned files in Finder for easy inspection. Navigate to any discovered file or folder with one click.")
                )

                // Cleanup Categories
                CleanupCategoriesCard(
                    title: L("Cleanup Categories"),
                    categories: [
                        (L("System Cache"), L("Temporary system files")),
                        (L("User Cache"), L("Application cache data")),
                        (L("Xcode DerivedData"), L("Build intermediates")),
                        (L("Xcode Archives"), L("Archived builds")),
                        (L("Xcode Simulators"), L("Old device simulators")),
                        (L("Project Build"), L("Build folders and artifacts")),
                        (L("CocoaPods"), L("Pod caches and builds")),
                        (L("Swift Package"), L("SPM build caches"))
                    ]
                )

                // Requirements
                RequirementsCard(
                    title: L("Requirements"),
                    items: [
                        L("macOS 14.0 or later"),
                        L("Swift 6.0 or later"),
                        L("Full disk access permission (for full scan)")
                    ]
                )

                // Safety Note
                SafetyNoteCard()
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

// MARK: - Cleanup Categories Card

private struct CleanupCategoriesCard: View {
    @LumiTheme private var theme
    let title: String
    let categories: [(String, String)]

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
                ForEach(categories, id: \.0) { category in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.0)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(1)

                        Text(category.1)
                            .font(.system(size: 11))
                            .foregroundColor(theme.textSecondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Safety Note Card

private struct SafetyNoteCard: View {
    @Environment(\.locale) private var locale
    @LumiTheme private var theme

    private func L(_ key: String) -> String {
        PluginDiskManagerLocalization.string(key, locale: locale)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 18))
                .foregroundStyle(theme.primary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(theme.primary.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(L("Safety First"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textPrimary)

                Text(L("Cache cleanup only removes safe, regenerable files. System files and user documents are never affected."))
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
    DiskManagerAboutView()
        .frame(width: 400, height: 900)
}
