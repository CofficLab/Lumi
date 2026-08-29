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
                tagline: String(localized: "Open the current project or any specified path in \(displayName).", bundle: .module),
                chips: [String(localized: "External App", bundle: .module), String(localized: "Agent Tool", bundle: .module), displayName],
                metrics: [
                    .init(value: "1", label: String(localized: "Agent tool", bundle: .module)),
                    .init(value: String(localized: "Low", bundle: .module), label: String(localized: "Permission risk", bundle: .module))
                ]
            )

            LandingSpotlight(
                icon: "arrow.up.forward.app",
                tint: theme.primary,
                title: String(localized: "A direct handoff to \(displayName)", bundle: .module),
                message: String(localized: "Keep the project in Lumi while sending the current project or a specific absolute path to the external application.", bundle: .module)
            ) {
                AppTag(toolName, style: .accent)
            }

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "square.grid.2x2") {
                LandingFeatureGrid(items: [
                    .init(
                        icon: "folder",
                        tint: theme.primary,
                        title: String(localized: "Current Project", bundle: .module),
                        description: String(localized: "Uses the open project as the default target when no path is supplied.", bundle: .module)
                    ),
                    .init(
                        icon: "arrow.right.doc.on.clipboard",
                        tint: theme.info,
                        title: String(localized: "Explicit Paths", bundle: .module),
                        description: String(localized: "Accepts an absolute path when you need to open a different project or folder.", bundle: .module)
                    ),
                    .init(
                        icon: "lock.shield",
                        tint: theme.success,
                        title: String(localized: "Low-Risk Action", bundle: .module),
                        description: String(localized: "Only asks the operating system to open the target in \(displayName).", bundle: .module)
                    )
                ])
            }

            LandingSection(title: String(localized: "How It Works", bundle: .module), icon: "arrow.triangle.branch.and.merge") {
                LandingStepFlow(steps: [
                    .init(title: String(localized: "Choose a target", bundle: .module), description: String(localized: "Ask the Agent to open the current project, or provide an absolute path.", bundle: .module), icon: "scope"),
                    .init(title: String(localized: "Resolve the application", bundle: .module), description: String(localized: "The plugin finds the installed \(displayName) app and uses its standard open action.", bundle: .module), icon: systemImage),
                    .init(title: String(localized: "Continue in context", bundle: .module), description: String(localized: "The selected project or path opens directly in \(displayName).", bundle: .module), icon: "checkmark.seal")
                ])
            }
        }
    }
}
