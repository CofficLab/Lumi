import KernelLumi
import LumiUI
import SwiftUI

// MARK: - About View

struct AboutView: View {
    @Environment(\.locale) private var locale
    @LumiTheme private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Feature Highlights
                FeatureHighlight(
                    icon: "server.rack",
                    title: L("Multi-Database Support"),
                    description: L("Connect to SQLite, MySQL, PostgreSQL, and Redis with optional SSL/TLS")
                )

                FeatureHighlight(
                    icon: "tablecells",
                    title: L("Unified Data Browser"),
                    description: L("Browse tables, views, and routines across engines with pagination and sorting")
                )

                FeatureHighlight(
                    icon: "square.and.pencil",
                    title: L("Safe Inline Editing"),
                    description: L("Edit cells and rows; preview the generated SQL and save in a transaction")
                )

                FeatureHighlight(
                    icon: "arrow.uturn.backward.circle",
                    title: L("Undo & Redo"),
                    description: L("Stage changes with full undo/redo before committing anything to the database")
                )

                FeatureHighlight(
                    icon: "curlybraces",
                    title: L("Custom SQL"),
                    description: L("Run your own SQL and inspect paginated, sortable results")
                )

                // How It Works
                HowItWorksCard(
                    title: coreL("about.section.howItWorks"),
                    steps: [
                        L("Add a connection or open a .sqlite file"),
                        L("Browse tables from the sidebar object tree"),
                        L("Edit data inline or run custom SQL"),
                        L("Preview changes and save in a transaction")
                    ]
                )

                // Tips
                TipsCard(
                    title: coreL("about.section.tips"),
                    tips: [
                        L("Double-click a cell to edit — changes queue until you save"),
                        L("Tables without a primary key are read-only"),
                        L("Use Preview SQL to review statements before saving")
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
        LumiPluginLocalization.string(key, bundle: KernelLumiResources.bundle, locale: locale)
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
