import LumiUI
import LumiKernel
import SwiftUI

// MARK: - About View

/// Plugin about view for App Icon Designer.
/// Introduces the plugin's icon design and export capabilities.
struct AppIconDesignerAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Feature Highlights
                FeatureHighlight(
                    icon: "paintbrush.fill",
                    title: AppIconDesignerLocalization.string("Vector Icon Design"),
                    description: AppIconDesignerLocalization.string("Create app icons with precise vector shapes including rectangles, circles, capsules, triangles, lines, symbols, and text.")
                )

                FeatureHighlight(
                    icon: "square.3.layers.3d",
                    title: AppIconDesignerLocalization.string("Layer Management"),
                    description: AppIconDesignerLocalization.string("Build complex icons with multiple layers. Control opacity, shadows, blur effects, and transform properties for each layer.")
                )

                FeatureHighlight(
                    icon: "paintpalette.fill",
                    title: AppIconDesignerLocalization.string("Rich Fill Options"),
                    description: AppIconDesignerLocalization.string("Fill shapes with solid colors, linear gradients, or radial gradients. Add stroke outlines with customizable width and color.")
                )

                FeatureHighlight(
                    icon: "square.and.arrow.up.fill",
                    title: AppIconDesignerLocalization.string("Xcode Export"),
                    description: AppIconDesignerLocalization.string("Export your designs as Xcode-ready AppIcon.appiconset with all required sizes for iOS, macOS, and watchOS.")
                )

                FeatureHighlight(
                    icon: "doc.richtext",
                    title: AppIconDesignerLocalization.string("SVG Export"),
                    description: AppIconDesignerLocalization.string("Export vector graphics in SVG format for web, documentation, or further editing in design tools.")
                )

                FeatureHighlight(
                    icon: "wand.and.stars",
                    title: AppIconDesignerLocalization.string("AI-Powered Tools"),
                    description: AppIconDesignerLocalization.string("Let AI help generate icon presets, apply styling, and lint your designs for best practices.")
                )

                // How It Works
                HowItWorksCard(
                    title: AppIconDesignerLocalization.string("How It Works"),
                    steps: [
                        AppIconDesignerLocalization.string("Create a new icon document or load an existing one"),
                        AppIconDesignerLocalization.string("Add shapes and arrange layers to build your design"),
                        AppIconDesignerLocalization.string("Customize fills, strokes, shadows, and transforms"),
                        AppIconDesignerLocalization.string("Preview your icon at multiple sizes"),
                        AppIconDesignerLocalization.string("Export as Xcode AppIcon set or SVG")
                    ]
                )

                // Supported Shapes
                SupportedShapesCard(
                    title: AppIconDesignerLocalization.string("Supported Shapes"),
                    shapes: [
                        ("rectangle", AppIconDesignerLocalization.string("Rectangles & Rounded Corners")),
                        ("circle.fill", AppIconDesignerLocalization.string("Circles & Ellipses")),
                        ("capsule.fill", AppIconDesignerLocalization.string("Capsules")),
                        ("triangle.fill", AppIconDesignerLocalization.string("Triangles")),
                        ("line.diagonal", AppIconDesignerLocalization.string("Lines")),
                        ("textformat", AppIconDesignerLocalization.string("Text Labels")),
                        ("star.fill", AppIconDesignerLocalization.string("SF Symbols"))
                    ]
                )

                // Requirements
                RequirementsCard(
                    title: AppIconDesignerLocalization.string("Requirements"),
                    items: [
                        AppIconDesignerLocalization.string("macOS 14.0 or later"),
                        AppIconDesignerLocalization.string("Swift 6.0 or later"),
                        AppIconDesignerLocalization.string("Xcode 15.0+ (for AppIcon export)")
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

// MARK: - Supported Shapes Card

private struct SupportedShapesCard: View {
    @LumiTheme private var theme
    let title: String
    let shapes: [(String, String)]

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
                ForEach(shapes, id: \.0) { shape in
                    HStack(spacing: 8) {
                        Image(systemName: shape.0)
                            .font(.system(size: 14))
                            .foregroundStyle(theme.primary)
                            .frame(width: 20)

                        Text(shape.1)
                            .font(.system(size: 12))
                            .foregroundColor(theme.textSecondary)
                            .lineLimit(1)

                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
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

#Preview {
    AppIconDesignerAboutView()
        .frame(width: 400, height: 700)
}
