import Foundation
import SwiftUI
import MagicKit

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
                        .help(String(localized: "LSP not available", table: "LSPToolbarEditor"))
                } else if lspService.isInitializing {
                    ProgressView()
                        .scaleEffect(0.5)
                        .help(String(localized: "LSP initializing...", table: "LSPToolbarEditor"))
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(AppUI.Color.semantic.success)
                        .help(String(localized: "LSP active", table: "LSPToolbarEditor"))
                }
            }
            .opacity(diagnosticsManager.errorCount > 0 || diagnosticsManager.warningCount > 0 || !lspService.isAvailable ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .help(String(localized: "Toggle Problems", table: "LSPToolbarEditor"))
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
            if !presentationModel.recentCommands.isEmpty {
                Section(String(localized: "Recently Used", table: "LumiEditor")) {
                    ForEach(presentationModel.recentCommands) { command in
                        commandButton(for: command, emphasizeRecent: true)
                    }
                }
            }

            ForEach(presentationModel.sections) { section in
                Section(section.title) {
                    ForEach(section.commands) { command in
                        commandButton(for: command)
                    }
                }
            }
        } label: {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 10))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
                .frame(width: 22, height: 22)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 22, height: 20)
        .fixedSize()
        .frame(maxWidth: 200)
        .help(String(localized: "LSP Actions", table: "LSPToolbarEditor"))
    }

    private var presentationModel: EditorCommandPresentationModel {
        state.editorCommandPresentationModel(
            categories: EditorCommandCategoryScope.lspActions
        )
    }

    @ViewBuilder
    private func commandButton(for command: EditorCommandSuggestion, emphasizeRecent: Bool = false) -> some View {
        Button {
            state.performEditorCommand(id: command.id)
        } label: {
            HStack(spacing: 8) {
                if emphasizeRecent {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(AppUI.Color.semantic.primary)
                }
                Label(command.title, systemImage: command.systemImage)
                if let shortcut = command.shortcut {
                    Spacer(minLength: 12)
                    Text(shortcut.displayText)
                        .foregroundColor(AppUI.Color.semantic.textTertiary)
                }
            }
        }
        .disabled(!command.isEnabled)
    }
}
