import EditorService
import Foundation
import LumiKernel
import SwiftUI

@MainActor
public final class SwiftRunCommandContributor: SuperEditorCommandContributor {
    public let id: String = "swift.commands"

    public init() {}

    public func provideCommands(
        context: EditorCommandContext,
        state: EditorState,
        textView: TextView?
    ) -> [EditorCommandSuggestion] {
        guard context.languageId == "swift" else { return [] }

        let buildRunManager = EditorSwiftWindowScopeRegistry.activeBuildRunManager
        let statusBarViewModel = EditorSwiftWindowScopeRegistry.activeStatusBarViewModel

        return [
            EditorCommandSuggestion(
                id: "swift.run",
                title: LumiPluginLocalization.string("Run", bundle: .module),
                systemImage: "play.fill",
                category: LumiPluginLocalization.string("Swift", bundle: .module),
                shortcut: EditorCommandShortcut(key: "r", modifiers: [.command]),
                order: 50,
                isEnabled: buildRunManager.canRun || buildRunManager.isActive
            ) {
                Task { @MainActor in
                    if buildRunManager.isActive {
                        buildRunManager.cancel()
                    } else {
                        await buildRunManager.refreshPreflight(
                            provider: statusBarViewModel.buildContextProvider,
                            projectPath: statusBarViewModel.activeProjectPath,
                            currentFileURL: state.currentFileURL,
                            fallbackScheme: statusBarViewModel.activeScheme,
                            fallbackConfiguration: statusBarViewModel.activeConfiguration,
                            fallbackDestinationQuery: statusBarViewModel.buildContextProvider?.activeDestination?.destinationQuery
                        )
                        buildRunManager.run(
                            provider: statusBarViewModel.buildContextProvider,
                            projectPath: statusBarViewModel.activeProjectPath,
                            currentFileURL: state.currentFileURL,
                            fallbackScheme: statusBarViewModel.activeScheme,
                            fallbackConfiguration: statusBarViewModel.activeConfiguration,
                            fallbackDestinationQuery: statusBarViewModel.buildContextProvider?.activeDestination?.destinationQuery
                        )
                    }
                }
            },
        ]
    }
}
