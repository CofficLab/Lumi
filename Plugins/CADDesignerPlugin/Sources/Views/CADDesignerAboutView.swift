import LumiUI
import LumiKernel
import SwiftUI

// MARK: - About View

/// Plugin about view for CAD Designer.
/// Introduces the plugin's aluminum profile CAD design capabilities.
struct CADDesignerAboutView: View {
    @Environment(\.locale) private var locale
    @LumiTheme private var theme

    private func L(_ key: String) -> String {
        CADDesignerLocalization.string(key, locale: locale)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Feature Highlights
                FeatureHighlight(
                    icon: "cube.fill",
                    title: L("3D Viewport"),
                    description: L("Design aluminum profile frames in an interactive 3D viewport with orbit camera, reference grid, and XYZ axis guides.")
                )

                FeatureHighlight(
                    icon: "square.stack.3d.up.fill",
                    title: L("Component Library"),
                    description: L("Access European standard 20/30/40 series aluminum profiles (12 specifications) plus connectors: brackets, bolts, sliding nuts, end caps, and hinges.")
                )

                FeatureHighlight(
                    icon: "link",
                    title: L("Assembly Relationships"),
                    description: L("Define connections between components with rigid, hinge, or bolt joint types to build accurate assembly structures.")
                )

                FeatureHighlight(
                    icon: "list.clipboard.fill",
                    title: L("BOM Generation"),
                    description: L("Automatically aggregate identical profiles and connectors into a bill of materials with quantities and specifications.")
                )

                FeatureHighlight(
                    icon: "scissors",
                    title: L("Cutting Optimization"),
                    description: L("Optimize cutting plans using First Fit Decreasing algorithm to minimize material waste and leftover scraps.")
                )

                FeatureHighlight(
                    icon: "camera.fill",
                    title: L("Export Options"),
                    description: L("Export viewport renders as PNG or PDF. Save and load projects in .cadproj JSON format.")
                )

                FeatureHighlight(
                    icon: "wand.and.stars",
                    title: L("AI-Powered Design"),
                    description: L("Natural language commands like 'build a 1m × 0.5m workbench' to automatically create frames with optimal component placement.")
                )

                // AI Tools
                AIToolsCard(
                    title: L("Available AI Tools"),
                    tools: [
                        ("cad_create_project", L("Create new CAD project")),
                        ("cad_place_profile", L("Place aluminum profile")),
                        ("cad_update_profile", L("Update component properties")),
                        ("cad_place_connector", L("Place connector")),
                        ("cad_connect_components", L("Define connections")),
                        ("cad_build_frame", L("Auto-generate rectangular frame")),
                        ("cad_generate_bom", L("Generate bill of materials")),
                        ("cad_optimize_cutting", L("Optimize cutting plan")),
                        ("cad_save_project", L("Save project to file")),
                        ("cad_load_project", L("Load project from file"))
                    ]
                )

                // Technical Details
                TechnicalDetailsCard(
                    title: L("Technical Details"),
                    details: [
                        (L("3D Engine"), L("SceneKit (native macOS)")),
                        (L("UI Framework"), L("SwiftUI + NSViewRepresentable")),
                        (L("Project Format"), L(".cadproj (JSON)")),
                        (L("Profile Standards"), L("EU 20/30/40 series"))
                    ]
                )

                // Requirements
                RequirementsCard(
                    title: L("Requirements"),
                    items: [
                        L("macOS 14.0 or later"),
                        L("Swift 6.0 or later"),
                        L("SceneKit-capable GPU")
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

// MARK: - AI Tools Card

private struct AIToolsCard: View {
    @LumiTheme private var theme
    let title: String
    let tools: [(String, String)]

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
                ForEach(tools, id: \.0) { tool in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tool.0)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(theme.primary)

                        Text(tool.1)
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

// MARK: - Technical Details Card

private struct TechnicalDetailsCard: View {
    @LumiTheme private var theme
    let title: String
    let details: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(details, id: \.0) { detail in
                    HStack {
                        Text(detail.0)
                            .font(.system(size: 13))
                            .foregroundColor(theme.textSecondary)

                        Spacer()

                        Text(detail.1)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(theme.textPrimary)
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
    CADDesignerAboutView()
        .frame(width: 400, height: 800)
}
