import EditorService
import EditorTabStripPlugin
import LumiCoreKit
import LumiUI
import os
import SwiftUI

/// Unified code editor plugin for the Lumi activity bar.
public enum EditorPanelPlugin: LumiPlugin {
    public static var verbose: Bool { false }
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.lumi-editor")
    public static let policy: LumiPluginPolicy = .optIn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "chevron.left.forwardslash.chevron.right"

    public static let info = LumiPluginInfo(
        id: "LumiEditor",
        displayName: LumiPluginLocalization.string("Code Editor", bundle: .module),
        description: String(
            localized: "Code editor with file tree, LSP, and workspace panels.",
            bundle: .module
        ),
        order: 77
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        guard context.resolve(LumiEditorServicing.self) != nil else {
            return []
        }

        return [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName,
                chatSection: .narrow,
                showsRail: true,
                showsPanelChrome: true
            ) {
                EditorPanelHostView()
            }
        ]
    }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [
            GetCurrentFileTool(),
            SetCurrentFileTool(),
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 16) {
                Text(info.displayName)
                    .font(.title2.weight(.semibold))
                Text(info.description)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        )
    }

    @MainActor
    public static func onboardingPages(context: LumiPluginContext) -> [AnyView] {
        [
            AnyView(
                PluginOnboardingPageView(
                    icon: iconName,
                    displayName: info.displayName,
                    description: info.description,
                    features: [
                        .init(
                            icon: "folder",
                            title: LumiPluginLocalization.string("Workspace", bundle: .module),
                            description: LumiPluginLocalization.string("File tree, tabs, and panels for your project", bundle: .module)
                        ),
                        .init(
                            icon: "text.magnifyingglass",
                            title: LumiPluginLocalization.string("LSP", bundle: .module),
                            description: LumiPluginLocalization.string("Diagnostics and language features built in", bundle: .module)
                        ),
                    ],
                    tip: LumiPluginLocalization.string("Open a project, then pick Code Editor from the sidebar.", bundle: .module)
                )
            )
        ]
    }
}
