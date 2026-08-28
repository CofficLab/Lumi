import LumiUI
import SwiftUI

/// Shared AboutView for the Open In plugin family.
public struct OpenInAboutView: View {
    @LumiTheme private var theme

    private let displayName: String
    private let systemImage: String
    private let toolName: String

    public init(displayName: String, systemImage: String, toolName: String) {
        self.displayName = displayName
        self.systemImage = systemImage
        self.toolName = toolName
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: systemImage,
                accent: theme.primary,
                tagline: "Open the current project or any specified path in \(displayName).",
                chips: ["External App", "Agent Tool", displayName],
                metrics: [
                    .init(value: "1", label: "Agent tool"),
                    .init(value: "Low", label: "Permission risk")
                ]
            )

            LandingSpotlight(
                icon: "arrow.up.forward.app",
                tint: theme.primary,
                title: "A direct handoff to \(displayName)",
                message: "Keep the project in Lumi while sending the current project or a specific absolute path to the external application."
            ) {
                AppTag(toolName, style: .accent)
            }

            LandingSection(title: "Core Capabilities", icon: "square.grid.2x2") {
                LandingFeatureGrid(items: [
                    .init(
                        icon: "folder",
                        tint: theme.primary,
                        title: "Current Project",
                        description: "Uses the open project as the default target when no path is supplied."
                    ),
                    .init(
                        icon: "arrow.right.doc.on.clipboard",
                        tint: theme.info,
                        title: "Explicit Paths",
                        description: "Accepts an absolute path when you need to open a different project or folder."
                    ),
                    .init(
                        icon: "lock.shield",
                        tint: theme.success,
                        title: "Low-Risk Action",
                        description: "Only asks the operating system to open the target in \(displayName)."
                    )
                ])
            }

            LandingSection(title: "How It Works", icon: "arrow.triangle.branch.and.merge") {
                LandingStepFlow(steps: [
                    .init(title: "Choose a target", description: "Ask the Agent to open the current project, or provide an absolute path.", icon: "scope"),
                    .init(title: "Resolve the application", description: "The plugin finds the installed \(displayName) app and uses its standard open action.", icon: systemImage),
                    .init(title: "Continue in context", description: "The selected project or path opens directly in \(displayName).", icon: "checkmark.seal")
                ])
            }
        }
    }
}
