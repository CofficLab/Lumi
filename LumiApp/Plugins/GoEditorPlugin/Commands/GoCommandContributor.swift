import Foundation
import SwiftUI
import MagicKit
import CodeEditTextView

/// Go 命令贡献者
///
/// 注册 go build / go test / go fmt / go mod tidy 等编辑器命令。
@MainActor
final class GoCommandContributor: SuperEditorCommandContributor {
    let id: String = "go.commands"

    private let buildManager: GoBuildManager

    init(buildManager: GoBuildManager) {
        self.buildManager = buildManager
    }

    func provideCommands(
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
        ]
    }

    // MARK: - Go Build

    private func buildCommand(state: EditorState) -> EditorCommandSuggestion {
        EditorCommandSuggestion(
            id: "go.build",
            title: String(localized: "Go Build", table: "GoEditor"),
            systemImage: "hammer",
            category: String(localized: "Go", table: "GoEditor"),
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
            title: String(localized: "Go Test", table: "GoEditor"),
            systemImage: "testtube.2",
            category: String(localized: "Go", table: "GoEditor"),
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
            title: String(localized: "Go Format", table: "GoEditor"),
            systemImage: "text.alignleft",
            category: String(localized: "Go", table: "GoEditor"),
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
            title: String(localized: "Go Mod Tidy", table: "GoEditor"),
            systemImage: "arrow.triangle.2.circlepath",
            category: String(localized: "Go", table: "GoEditor"),
            order: 400,
            isEnabled: true
        ) { [weak self, weak state] in
            guard let self, let state else { return }
            Task { await self.runModTidy(state: state) }
        }
    }

    // MARK: - Execution

    private func runBuild(state: EditorState) async {
        guard let projectRoot = resolveProjectRoot(state: state) else { return }
        await buildManager.build(workingDirectory: projectRoot)
    }

    private func runTest(state: EditorState) async {
        guard let projectRoot = resolveProjectRoot(state: state) else { return }
        await buildManager.test(workingDirectory: projectRoot)
    }

    private func runFmt(state: EditorState) async {
        guard let projectRoot = resolveProjectRoot(state: state) else { return }
        let runner = GoRunner()
        let result = await runner.execute(
            command: "fmt",
            arguments: ["./..."],
            workingDirectory: projectRoot
        )
        if GoEditorPlugin.verbose {
            GoEditorPlugin.logger.info("\(GoEditorPlugin.t)go fmt: exit=\(result.exitCode)")
        }
    }

    private func runModTidy(state: EditorState) async {
        guard let projectRoot = resolveProjectRoot(state: state) else { return }
        let runner = GoRunner()
        let result = await runner.execute(
            command: "mod",
            arguments: ["tidy"],
            workingDirectory: projectRoot
        )
        if GoEditorPlugin.verbose {
            GoEditorPlugin.logger.info("\(GoEditorPlugin.t)go mod tidy: exit=\(result.exitCode)")
        }
    }

    // MARK: - Helpers

    private func resolveProjectRoot(state: EditorState) -> String? {
        guard let fileURL = state.currentFileURL else { return nil }
        let root = GoProjectDetector.findProjectRoot(from: fileURL)
        if root == nil, GoEditorPlugin.verbose {
            GoEditorPlugin.logger.warning("\(GoEditorPlugin.t)未找到 go.mod 项目根目录")
        }
        return root
    }
}
