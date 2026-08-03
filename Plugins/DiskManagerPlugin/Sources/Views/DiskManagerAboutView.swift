import LumiUI
import LumiKernel
import SwiftUI

// MARK: - About View

/// Plugin about view for Disk Manager.
/// Introduces the plugin's disk analysis and cleanup capabilities.
struct DiskManagerAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Feature Highlights
                FeatureHighlight(
                    icon: "chart.pie.fill",
                    title: PluginDiskManagerLocalization.string("Disk Usage Overview"),
                    description: PluginDiskManagerLocalization.string("View total, used, and available disk space at a glance. Monitor storage health and identify space consumption patterns.")
                )

                FeatureHighlight(
                    icon: "doc.fill",
                    title: PluginDiskManagerLocalization.string("Large File Scanner"),
                    description: PluginDiskManagerLocalization.string("Discover large files consuming your disk space. Scan any directory to find files sorted by size for easy cleanup.")
                )

                FeatureHighlight(
                    icon: "folder.fill",
                    title: PluginDiskManagerLocalization.string("Directory Analysis"),
                    description: PluginDiskManagerLocalization.string("Visualize directory size breakdowns with interactive tree views. Identify which folders are taking up the most space.")
                )

                FeatureHighlight(
                    icon: "trash.fill",
                    title: PluginDiskManagerLocalization.string("Cache Cleanup"),
                    description: PluginDiskManagerLocalization.string("Clean up system caches to free up disk space. Safely remove temporary files without affecting system stability.")
                )

                FeatureHighlight(
                    icon: "hammer.fill",
                    title: PluginDiskManagerLocalization.string("Xcode Cleanup"),
                    description: PluginDiskManagerLocalization.string("Free up significant space by removing Xcode-derived data, old simulators, build products, and archives.")
                )

                FeatureHighlight(
                    icon: "folder.badge.gearshape",
                    title: PluginDiskManagerLocalization.string("Project Cleanup"),
                    description: PluginDiskManagerLocalization.string("Scan project directories for removable build artifacts like DerivedData, build folders, and CocoaPods caches.")
                )

                FeatureHighlight(
                    icon: "magnifyingglass",
                    title: PluginDiskManagerLocalization.string("Finder Integration"),
                    description: PluginDiskManagerLocalization.string("Quickly reveal scanned files in Finder for easy inspection. Navigate to any discovered file or folder with one click.")
                )

                // Cleanup Categories
                CleanupCategoriesCard(
                    title: PluginDiskManagerLocalization.string("Cleanup Categories"),
                    categories: [
                        (PluginDiskManagerLocalization.string("System Cache"), PluginDiskManagerLocalization.string("Temporary system files")),
                        (PluginDiskManagerLocalization.string("User Cache"), PluginDiskManagerLocalization.string("Application cache data")),
                        (PluginDiskManagerLocalization.string("Xcode DerivedData"), PluginDiskManagerLocalization.string("Build intermediates")),
                        (PluginDiskManagerLocalization.string("Xcode Archives"), PluginDiskManagerLocalization.string("Archived builds")),
                        (PluginDiskManagerLocalization.string("Xcode Simulators"), PluginDiskManagerLocalization.string("Old device simulators")),
                        (PluginDiskManagerLocalization.string("Project Build"), PluginDiskManagerLocalization.string("Build folders and artifacts")),
                        (PluginDiskManagerLocalization.string("CocoaPods"), PluginDiskManagerLocalization.string("Pod caches and builds")),
                        (PluginDiskManagerLocalization.string("Swift Package"), PluginDiskManagerLocalization.string("SPM build caches"))
                    ]
                )

                // Requirements
                RequirementsCard(
                    title: PluginDiskManagerLocalization.string("Requirements"),
                    items: [
                        PluginDiskManagerLocalization.string("macOS 14.0 or later"),
                        PluginDiskManagerLocalization.string("Swift 6.0 or later"),
                        PluginDiskManagerLocalization.string("Full disk access permission (for full scan)")
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
    @LumiTheme private var theme

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
                Text(PluginDiskManagerLocalization.string("Safety First"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textPrimary)

                Text(PluginDiskManagerLocalization.string("Cache cleanup only removes safe, regenerable files. System files and user documents are never affected."))
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
