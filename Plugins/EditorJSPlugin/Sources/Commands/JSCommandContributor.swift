import Foundation
import EditorService
import SwiftUI
import EditorTextView
import LumiCoreKit

@MainActor
public final class JSCommandContributor: SuperEditorCommandContributor {
    public let id = "js.commands"

    private let taskManager: JSTaskManager

    public init(taskManager: JSTaskManager) {
        self.taskManager = taskManager
    }

    public func provideCommands(
        context: EditorCommandContext,
        state: EditorState,
        textView: TextView?
    ) -> [EditorCommandSuggestion] {
        guard isJSLanguage(context.languageId) else { return [] }
        let projectPath = resolveProjectRoot(state: state)
        let package = projectPath.flatMap { PackageJSONParser.parse(projectPath: $0) }

        var commands = [
            buildCommand(state: state, projectPath: projectPath, package: package),
            testCommand(state: state, projectPath: projectPath, package: package),
            lintCommand(state: state, projectPath: projectPath),
            formatCommand(state: state, projectPath: projectPath),
            debugCommand(state: state, projectPath: projectPath),
        ]

        if let package {
            commands.append(contentsOf: package.scripts.keys.sorted().prefix(8).map {
                scriptCommand(script: $0, state: state, projectPath: projectPath)
            })
        }

        return commands
    }

    private func buildCommand(state: EditorState, projectPath: String?, package: JSPackageInfo?) -> EditorCommandSuggestion {
        EditorCommandSuggestion(
            id: "js.build",
            title: LumiPluginLocalization.string("JS Build", bundle: .module),
            systemImage: "hammer",
            category: LumiPluginLocalization.string("JavaScript", bundle: .module),
            shortcut: EditorCommandShortcut(key: "b", modifiers: [.command]),
            order: 100,
            isEnabled: projectPath != nil
        ) { [weak self, weak state] in
            guard let self, let state, let projectPath = self.resolveProjectRoot(state: state) else { return }
            Task { await self.taskManager.build(projectPath: projectPath, package: PackageJSONParser.parse(projectPath: projectPath)) }
        }
    }

    private func testCommand(state: EditorState, projectPath: String?, package: JSPackageInfo?) -> EditorCommandSuggestion {
        EditorCommandSuggestion(
            id: "js.test",
            title: LumiPluginLocalization.string("JS Test", bundle: .module),
            systemImage: "testtube.2",
            category: LumiPluginLocalization.string("JavaScript", bundle: .module),
            order: 200,
            isEnabled: projectPath != nil && TestRunnerDetector.preferredScript(package: package) != nil
        ) { [weak self, weak state] in
            guard let self, let state, let projectPath = self.resolveProjectRoot(state: state) else { return }
            Task { await self.taskManager.test(projectPath: projectPath, package: PackageJSONParser.parse(projectPath: projectPath)) }
        }
    }

    private func lintCommand(state: EditorState, projectPath: String?) -> EditorCommandSuggestion {
        EditorCommandSuggestion(
            id: "js.lint",
            title: LumiPluginLocalization.string("ESLint Current File", bundle: .module),
            systemImage: "checklist",
            category: LumiPluginLocalization.string("JavaScript", bundle: .module),
            order: 300,
            isEnabled: projectPath != nil
        ) { [weak self, weak state] in
            guard let self, let state, let projectPath = self.resolveProjectRoot(state: state) else { return }
            Task { await self.taskManager.lint(fileURL: state.currentFileURL, projectPath: projectPath) }
        }
    }

    private func formatCommand(state: EditorState, projectPath: String?) -> EditorCommandSuggestion {
        EditorCommandSuggestion(
            id: "js.format.prettier",
            title: LumiPluginLocalization.string("Format with Prettier", bundle: .module),
            systemImage: "text.alignleft",
            category: LumiPluginLocalization.string("JavaScript", bundle: .module),
            shortcut: EditorCommandShortcut(key: "l", modifiers: [.shift, .command]),
            order: 400,
            isEnabled: projectPath != nil
        ) { [weak self, weak state] in
            guard let self, let state else { return }
            Task { await self.taskManager.format(fileURL: state.currentFileURL, projectPath: self.resolveProjectRoot(state: state)) }
        }
    }

    private func debugCommand(state: EditorState, projectPath: String?) -> EditorCommandSuggestion {
        EditorCommandSuggestion(
            id: "js.debug.node",
            title: LumiPluginLocalization.string("Debug Current File", bundle: .module),
            systemImage: "ladybug",
            category: LumiPluginLocalization.string("JavaScript", bundle: .module),
            order: 500,
            isEnabled: projectPath != nil && state.currentFileURL != nil
        ) { [weak state] in
            guard let state, let projectPath = projectPath else { return }
            let config = NodeDAPAdapter.defaultLaunch(fileURL: state.currentFileURL, projectPath: projectPath)
            _ = NodeDAPAdapter.commandLine(for: config)
        }
    }

    private func scriptCommand(script: String, state: EditorState, projectPath: String?) -> EditorCommandSuggestion {
        EditorCommandSuggestion(
            id: "js.script.\(script)",
            title: String(format: LumiPluginLocalization.string("Run Script: %@", bundle: .module), script),
            systemImage: "terminal",
            category: LumiPluginLocalization.string("npm Scripts", bundle: .module),
            order: 600,
            isEnabled: projectPath != nil
        ) { [weak self, weak state] in
            guard let self, let state, let projectPath = self.resolveProjectRoot(state: state) else { return }
            Task { await self.taskManager.run(script: script, projectPath: projectPath) }
        }
    }

    private func resolveProjectRoot(state: EditorState) -> String? {
        guard let fileURL = state.currentFileURL else { return nil }
        return WorkspaceDetector.findRoot(from: fileURL)?.path
    }

    private func isJSLanguage(_ languageId: String) -> Bool {
        languageId == "javascript" || languageId == "typescript"
    }
}
