import AgentToolKit
import EditorService
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
        guard
            let projectPathStore = context.resolve(LumiCurrentProjectPathStoring.self) as? LumiCurrentProjectPathStore,
            let editor = context.resolve(LumiEditorServicing.self)
        else {
            return []
        }

        return [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                EditorPanelHostView(projectPathStore: projectPathStore, editor: editor)
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
              let service = context.resolve(LumiEditorServicing.self)?.editorService
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
            LumiStatusBarItem(
                id: "\(info.id).cursor",
                title: "Cursor",
                systemImage: "cursorarrow",
                placement: .trailing,
                statusBarView: {
                    EditorCursorStatusBarView(service: service)
                }
            ),
        ]
    }
}

private struct EditorCursorStatusBarView: View {
    @ObservedObject var service: EditorService

    var body: some View {
        Text("Ln \(service.cursorLine + 1), Col \(service.cursorColumn + 1)")
            .font(.caption)
            .monospacedDigit()
    }
}
