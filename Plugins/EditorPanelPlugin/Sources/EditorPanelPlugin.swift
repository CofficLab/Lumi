import AgentToolKit
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
    public static let category: LumiPluginCategory = .development
    public static let iconName = "chevron.left.forwardslash.chevron.right"

    public static let info = LumiPluginInfo(
        id: "LumiEditor",
        displayName: String(localized: "Code Editor", bundle: .module),
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
                showsPanelChrome: true
            ) {
                EditorPanelHostView()
            }
        ]
    }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [
            GetCurrentFileTool().asLumiAgentTool(),
            SetCurrentFileTool().asLumiAgentTool(),
            AddSwiftPackageTool().asLumiAgentTool(),
            ListSwiftPackagesTool().asLumiAgentTool(),
            GenerateXcodeProjectTool().asLumiAgentTool(),
        ]
    }

    @MainActor
    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        guard context.activeSectionID == info.id,
              context.resolve(LumiEditorServicing.self) != nil
        else {
            return []
        }

        return [
            LumiStatusBarItem(
                id: "\(info.id).lsp",
                title: "LSP",
                systemImage: "waveform.path.ecg",
                placement: .trailing,
                statusBarView: {
                    LSPDiagnosticStatusBarItem()
                }
            ),
        ]
    }
}
