import LumiUI
import SwiftUI
import LumiKernel

/// Swift Editor plugin about view.
/// Introduces the plugin's Swift language support and tree-sitter highlighting capabilities.
struct EditorSwiftAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Feature Highlights
                FeatureHighlight(
                    icon: "swift",
                    title: String(localized: "Swift Language Support"),
                    description: String(localized: "Provides comprehensive Swift language support including syntax highlighting, keyword hovers, and semantic analysis.")
                )

                FeatureHighlight(
                    icon: "textformat.abc",
                    title: String(localized: "Tree-sitter Integration"),
                    description: String(localized: "Uses tree-sitter for robust and fast syntax parsing, enabling accurate code structure understanding.")
                )

                FeatureHighlight(
                    icon: "xcode",
                    title: String(localized: "Xcode Project Status"),
                    description: String(localized: "Displays current Xcode project, scheme, and build configuration in the status bar for quick reference.")
                )

                FeatureHighlight(
                    icon: "hammer.fill",
                    title: String(localized: "Swift Build Integration"),
                    description: String(localized: "Run Swift builds directly from Lumi with real-time build output and error navigation.")
                )

                FeatureHighlight(
                    icon: "plus.circle.fill",
                    title: String(localized: "Smart Completions"),
                    description: String(localized: "Context-aware completions for Swift primitive types, keywords, and project symbols.")
                )

                FeatureHighlight(
                    icon: "arrow.right.circle.fill",
                    title: String(localized: "Code Actions"),
                    description: String(localized: "Quick actions for Swift code selection, including run actions and context-specific operations.")
                )

                // Supported Features
                SupportedFeaturesCard(
                    title: String(localized: "Supported Features"),
                    features: [
                        ("Syntax Highlighting", String(localized: "Full Swift syntax coloring")),
                        ("Keyword Hovers", String(localized: "Documentation on hover")),
                        ("Code Completions", String(localized: "Type-aware suggestions")),
                        ("Build Status", String(localized: "Real-time build feedback")),
                        ("Error Navigation", String(localized: "Jump to diagnostics")),
                        ("Package Support", String(localized: "Swift Package Manager integration"))
                    ]
                )

                // How It Works
                HowItWorksCard(
                    title: String(localized: "How It Works"),
                    steps: [
                        String(localized: "Parses Swift files using tree-sitter grammar"),
                        String(localized: "Provides syntax highlighting and hovers"),
                        String(localized: "Integrates with Xcode build system"),
                        String(localized: "Displays project context in status bar")
                    ]
                )

                // Requirements
                RequirementsCard(
                    title: String(localized: "Requirements"),
                    items: [
                        String(localized: "macOS 14.0 or later"),
                        String(localized: "Xcode 15.0 or later (for build integration)"),
                        String(localized: "Swift 5.9 or later")
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

// MARK: - Supported Features Card

private struct SupportedFeaturesCard: View {
    @LumiTheme private var theme
    let title: String
    let features: [(String, String)]

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
                ForEach(features, id: \.0) { feature in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(theme.primary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.0)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(theme.textPrimary)

                            Text(feature.1)
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

#Preview {
    EditorSwiftAboutView()
        .frame(width: 500, height: 900)
}
