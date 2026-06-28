import Foundation
import SuperLogKit
import EditorService
import SwiftUI
import LumiCoreKit

/// Vue 开发工具命令贡献器
///
/// 提供 Vue 项目专属的开发服务器和调试命令：
/// - 启动 Vite 开发服务器 (⇧⌘R)
/// - 构建生产版本
/// - 预览 (Vite Preview)
/// - 打开开发服务器
@MainActor
final class VueDevCommandContributor: SuperEditorCommandContributor, SuperLog {
    let id = "vue.dev-commands"

    /// 已知的运行中开发服务器端口
    private static var knownPorts: [String: Int] = [:]

    func provideCommands(
        context: EditorCommandContext,
        state: EditorState,
        textView: TextView?
    ) -> [EditorCommandSuggestion] {
        guard context.languageId == "vue" else { return [] }
        guard let projectRoot = resolveProjectRoot(state: state) else { return [] }

        let viteConfig = ViteBridge.detect(projectPath: projectRoot)
        let isViteProject = viteConfig != nil && viteConfig?.isVueProject == true

        guard isViteProject else { return [] }

        var commands: [EditorCommandSuggestion] = []
        let isRunning = ViteBridge.isDevServerRunning(
            projectPath: projectRoot,
            port: viteConfig?.devPort ?? 5173
        )

        if isRunning {
            commands.append(openDevServerCommand(state: state, viteConfig: viteConfig))
        } else {
            commands.append(startDevServerCommand(state: state))
        }

        commands.append(buildProductionCommand(state: state))
        commands.append(previewCommand(state: state))

        return commands
    }

    // MARK: - Start Dev Server

    private func startDevServerCommand(state: EditorState) -> EditorCommandSuggestion {
        EditorCommandSuggestion(
            id: "vue.dev.start",
            title: LumiPluginLocalization.string("Start Dev Server", bundle: .module),
            systemImage: "play.fill",
            category: LumiPluginLocalization.string("Vue", bundle: .module),
            shortcut: EditorCommandShortcut(key: "r", modifiers: [.shift, .command]),
            order: 100,
            isEnabled: true
        ) { [weak self, weak state] in
            guard let self, let state else { return }
            self.startDevServer(state: state)
        }
    }

    // MARK: - Open Dev Server

    private func openDevServerCommand(state: EditorState, viteConfig: ViteBridge.ViteConfig?) -> EditorCommandSuggestion {
        let port = viteConfig?.devPort ?? 5173
        let host = viteConfig?.devHost ?? "localhost"
        let url = "http://\(host):\(port)"

        return EditorCommandSuggestion(
            id: "vue.dev.open",
            title: LumiPluginLocalization.string("Open Dev Server", bundle: .module),
            systemImage: "safari",
            category: LumiPluginLocalization.string("Vue", bundle: .module),
            shortcut: EditorCommandShortcut(key: "r", modifiers: [.shift, .command, .option]),
            order: 150,
            isEnabled: true
        ) {
            if let url = URL(string: url) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - Build Production

    private func buildProductionCommand(state: EditorState) -> EditorCommandSuggestion {
        EditorCommandSuggestion(
            id: "vue.dev.build",
            title: LumiPluginLocalization.string("Build Production", bundle: .module),
            systemImage: "archivebox",
            category: LumiPluginLocalization.string("Vue", bundle: .module),
            order: 200,
            isEnabled: true
        ) { [weak self, weak state] in
            guard let self, let state else { return }
            self.runBuild(state: state)
        }
    }

    // MARK: - Preview

    private func previewCommand(state: EditorState) -> EditorCommandSuggestion {
        EditorCommandSuggestion(
            id: "vue.dev.preview",
            title: LumiPluginLocalization.string("Preview Build", bundle: .module),
            systemImage: "eye.fill",
            category: LumiPluginLocalization.string("Vue", bundle: .module),
            order: 250,
            isEnabled: true
        ) { [weak self, weak state] in
            guard let self, let state else { return }
            self.runPreview(state: state)
        }
    }

    // MARK: - Execution

    private func startDevServer(state: EditorState) {
        guard let projectRoot = resolveProjectRoot(state: state) else { return }
        let command = ViteBridge.devServerCommand(projectPath: projectRoot)

        if EditorVuePlugin.verbose {
            if EditorVuePlugin.verbose {
                            EditorVuePlugin.logger.info("\(EditorVuePlugin.t)启动 Vite 开发服务器: \(command)")
            }
        }

        // 在终端中执行
        Task {
            await runShellCommand(command: command, workingDirectory: projectRoot)
        }
    }

    private func runBuild(state: EditorState) {
        guard let projectRoot = resolveProjectRoot(state: state) else { return }
        let command = ViteBridge.buildCommand(projectPath: projectRoot)

        if EditorVuePlugin.verbose {
            if EditorVuePlugin.verbose {
                            EditorVuePlugin.logger.info("\(EditorVuePlugin.t)执行构建: \(command)")
            }
        }

        Task {
            await runShellCommand(command: command, workingDirectory: projectRoot)
        }
    }

    private func runPreview(state: EditorState) {
        guard let projectRoot = resolveProjectRoot(state: state) else { return }
        let command = "npm run preview"

        if EditorVuePlugin.verbose {
            if EditorVuePlugin.verbose {
                            EditorVuePlugin.logger.info("\(EditorVuePlugin.t)执行预览: \(command)")
            }
        }

        Task {
            await runShellCommand(command: command, workingDirectory: projectRoot)
        }
    }

    // MARK: - Helpers

    private func resolveProjectRoot(state: EditorState) -> String? {
        guard let fileURL = state.currentFileURL else { return nil }
        var currentURL = fileURL.deletingLastPathComponent()

        // 向上查找包含 package.json 的目录
        while currentURL.path != "/" {
            let packagePath = currentURL.appendingPathComponent("package.json").path
            if FileManager.default.fileExists(atPath: packagePath) {
                return currentURL.path
            }
            currentURL = currentURL.deletingLastPathComponent()
        }

        // 如果没有找到 package.json，返回文件所在目录
        return fileURL.deletingLastPathComponent().path
    }

    private func runShellCommand(command: String, workingDirectory: String) async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            if EditorVuePlugin.verbose {
                if EditorVuePlugin.verbose {
                                    EditorVuePlugin.logger.info("\(EditorVuePlugin.t)命令输出: \(output.prefix(500))")
                }
            }
        } catch {
            if EditorVuePlugin.verbose {
                            EditorVuePlugin.logger.error("\(EditorVuePlugin.t)执行命令失败: \(error.localizedDescription)")
            }
        }
    }
}
