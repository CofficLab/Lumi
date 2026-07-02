import Foundation
import SuperLogKit
import EditorService

import SwiftUI
import LumiCoreKit

/// Go 命令贡献者
///
/// 注册 go build / go test / go fmt / go mod tidy 等编辑器命令。
@MainActor
public final class GoCommandContributor: SuperEditorCommandContributor, SuperLog {
    public let id: String = "go.commands"

    private let buildManager: GoBuildManager
    private let testManager: GoTestManager

    public init(buildManager: GoBuildManager, testManager: GoTestManager) {
        self.buildManager = buildManager
        self.testManager = testManager
    }

    public func provideCommands(
        context: EditorCommandContext,
        state: EditorState,
        textView: TextView?
    ) -> [EditorCommandSuggestion] {
        guard context.languageId == "go" else { return [] }

        return [
            buildCommand(state: state),
            testCommand(state: state),
            fmtCommand(state: state),
            modTidyCommand(state: state),
            debugCommand(state: state),
        ]
    }

    // MARK: - Go Build

    private func buildCommand(state: EditorState) -> EditorCommandSuggestion {
        EditorCommandSuggestion(
            id: "go.build",
            title: LumiPluginLocalization.string("Go Build", bundle: .module),
            systemImage: "hammer",
            category: LumiPluginLocalization.string("Go", bundle: .module),
            shortcut: EditorCommandShortcut(key: "b", modifiers: [.command]),
            order: 100,
            isEnabled: true
        ) { [weak self, weak state] in
            guard let self, let state else { return }
            Task { await self.runBuild(state: state) }
        }
    }

    // MARK: - Go Test

    private func testCommand(state: EditorState) -> EditorCommandSuggestion {
        EditorCommandSuggestion(
            id: "go.test",
            title: LumiPluginLocalization.string("Go Test", bundle: .module),
            systemImage: "testtube.2",
            category: LumiPluginLocalization.string("Go", bundle: .module),
            order: 200,
            isEnabled: true
        ) { [weak self, weak state] in
            guard let self, let state else { return }
            Task { await self.runTest(state: state) }
        }
    }

    // MARK: - Go Fmt

    private func fmtCommand(state: EditorState) -> EditorCommandSuggestion {
        EditorCommandSuggestion(
            id: "go.fmt",
            title: LumiPluginLocalization.string("Go Format", bundle: .module),
            systemImage: "text.alignleft",
            category: LumiPluginLocalization.string("Go", bundle: .module),
            shortcut: EditorCommandShortcut(key: "l", modifiers: [.shift, .command]),
            order: 300,
            isEnabled: true
        ) { [weak self, weak state] in
            guard let self, let state else { return }
            Task { await self.runFmt(state: state) }
        }
    }

    // MARK: - Go Mod Tidy

    private func modTidyCommand(state: EditorState) -> EditorCommandSuggestion {
        EditorCommandSuggestion(
            id: "go.mod.tidy",
            title: LumiPluginLocalization.string("Go Mod Tidy", bundle: .module),
            systemImage: "arrow.triangle.2.circlepath",
            category: LumiPluginLocalization.string("Go", bundle: .module),
            order: 400,
            isEnabled: true
        ) { [weak self, weak state] in
            guard let self, let state else { return }
            Task { await self.runModTidy(state: state) }
        }
    }

    // MARK: - Go Debug

    private func debugCommand(state: EditorState) -> EditorCommandSuggestion {
        EditorCommandSuggestion(
            id: "go.debug.current-file",
            title: LumiPluginLocalization.string("Debug Current Go File", bundle: .module),
            systemImage: "ladybug",
            category: LumiPluginLocalization.string("Go", bundle: .module),
            order: 500,
            isEnabled: state.currentFileURL != nil
        ) { [weak self, weak state] in
            guard let self, let state else { return }
            self.prepareDebugLaunch(state: state)
        }
    }

    // MARK: - Execution

    private func runBuild(state: EditorState) async {
        guard let projectRoot = resolveProjectRoot(state: state) else { return }
        await buildManager.build(workingDirectory: projectRoot)
    }

    private func runTest(state: EditorState) async {
        guard let projectRoot = resolveProjectRoot(state: state) else { return }
        await testManager.test(workingDirectory: projectRoot)
    }

    private func runFmt(state: EditorState) async {
        guard let projectRoot = resolveProjectRoot(state: state) else { return }
        await buildManager.format(workingDirectory: projectRoot)
    }

    private func runModTidy(state: EditorState) async {
        guard let projectRoot = resolveProjectRoot(state: state) else { return }
        await buildManager.tidyModule(workingDirectory: projectRoot)
    }

    private func prepareDebugLaunch(state: EditorState) {
        guard let projectRoot = resolveProjectRoot(state: state) else { return }
        let config = DelveAdapter.defaultLaunch(
            fileURL: state.currentFileURL,
            projectPath: projectRoot
        )
        _ = DelveAdapter.commandLine(for: config)
    }

    // MARK: - Helpers

    private func resolveProjectRoot(state: EditorState) -> String? {
        guard let fileURL = state.currentFileURL else { return nil }
        let root = GoProjectDetector.findProjectRoot(from: fileURL)
        if root == nil {
            print("[Go] 未找到 go.mod 项目根目录")
        }
        return root
    }
}
