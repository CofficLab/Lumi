import Foundation
import SwiftUI
import MagicKit

@objc(LumiLSPToolbarEditorPlugin)
@MainActor
final class LSPToolbarEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.lsp.toolbar"
    let displayName: String = "LSP Toolbar"
    let order: Int = 19

    func register(into registry: EditorExtensionRegistry) {
        registry.registerToolbarContributor(LSPToolbarContributor())
    }
}

@MainActor
final class LSPToolbarContributor: EditorToolbarContributor {
    let id: String = "builtin.lsp.toolbar"

    func provideToolbarItems(state: EditorState) -> [EditorToolbarItemSuggestion] {
        [
            .init(
                id: "builtin.lsp.status-indicator",
                order: 10,
                placement: .center,
                content: { AnyView(LSPStatusToolbarItem(state: $0)) }
            ),
            .init(
                id: "builtin.lsp.progress-indicator",
                order: 20,
                placement: .center,
                content: { AnyView(LSPProgressToolbarItem(state: $0)) }
            ),
            .init(
                id: "builtin.lsp.actions-menu",
                order: 30,
                placement: .center,
                content: { AnyView(LSPActionsToolbarItem(state: $0)) }
            )
        ]
    }
}

private struct LSPStatusToolbarItem: View {
    @ObservedObject var state: EditorState
    @ObservedObject private var lspService: LSPService
    @StateObject private var diagnosticsManager: DiagnosticsManager

    init(state: EditorState) {
        self._state = ObservedObject(wrappedValue: state)
        self._lspService = ObservedObject(wrappedValue: state.lspServiceInstance)
        self._diagnosticsManager = StateObject(
            wrappedValue: DiagnosticsManager(lspService: state.lspServiceInstance)
        )
    }

    var body: some View {
        Button {
            state.performEditorCommand(id: "builtin.toggle-problems")
        } label: {
            HStack(spacing: 8) {
                if diagnosticsManager.errorCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(AppUI.Color.semantic.error)
                        Text("\(diagnosticsManager.errorCount)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(AppUI.Color.semantic.error)
                    }
                }

                if diagnosticsManager.warningCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(AppUI.Color.semantic.warning)
                        Text("\(diagnosticsManager.warningCount)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(AppUI.Color.semantic.warning)
                    }
                }

                if !lspService.isAvailable {
                    Image(systemName: "circle")
                        .font(.system(size: 6))
                        .foregroundColor(AppUI.Color.semantic.textTertiary)
                        .help(String(localized: "LSP not available", table: "LumiEditor"))
                } else if lspService.isInitializing {
                    ProgressView()
                        .scaleEffect(0.5)
                        .help(String(localized: "LSP initializing...", table: "LumiEditor"))
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(AppUI.Color.semantic.success)
                        .help(String(localized: "LSP active", table: "LumiEditor"))
                }
            }
            .opacity(diagnosticsManager.errorCount > 0 || diagnosticsManager.warningCount > 0 || !lspService.isAvailable ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .help(String(localized: "Toggle Problems", table: "LumiEditor"))
    }
}

private struct LSPProgressToolbarItem: View {
    @ObservedObject var state: EditorState
    @ObservedObject private var lspService: LSPService

    init(state: EditorState) {
        self._state = ObservedObject(wrappedValue: state)
        self._lspService = ObservedObject(wrappedValue: state.lspServiceInstance)
    }

    var body: some View {
        Group {
            if !lspService.progressProvider.activeTasks.isEmpty {
                LSPProgressIndicatorView(provider: lspService.progressProvider)
                    .frame(maxWidth: 200)
            }
        }
    }
}

private struct LSPActionsToolbarItem: View {
    @ObservedObject var state: EditorState

    var body: some View {
        Menu {
            let commands = state.editorCommandSuggestions()
            ForEach(commands) { command in
                Button {
                    command.action()
                } label: {
                    Label(command.title, systemImage: command.systemImage)
                }
                .disabled(!command.isEnabled)
            }
        } label: {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 10))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
                .frame(width: 22, height: 22)
        }
        .menuStyle(.borderlessButton)
        .frame(height: 20)
        .help(String(localized: "LSP Actions", table: "LumiEditor"))
    }
}
