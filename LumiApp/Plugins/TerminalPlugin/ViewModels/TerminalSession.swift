import AppKit
import Foundation
import SwiftTerm
import SwiftUI

@MainActor
final class TerminalSession: ObservableObject, Identifiable {
    let id = UUID()
    @Published var title: String = "Terminal"
    @Published var isConnected: Bool = false

    /// 自定义终端视图（零尺寸保护 + 无障碍）
    let terminalView: LumiTerminalView
    private let initialWorkingDirectory: String?
    /// KVO 观察系统外观变化
    private var appearanceObservation: NSKeyValueObservation?
    /// 当前编辑器主题 ID（用于终端颜色同步）
    private var currentThemeId: String

    init(workingDirectory: String? = nil) {
        self.initialWorkingDirectory = workingDirectory
        self.terminalView = LumiTerminalView(frame: .zero)

        // 读取当前统一主题并映射为编辑器主题
        if let savedThemeId = ThemeStatusBarPluginLocalStore.shared.loadSelectedThemeID() {
            self.currentThemeId = ThemeVM.editorThemeID(for: savedThemeId)
        } else {
            self.currentThemeId = "xcode-dark"
        }

        setupTerminal()
    }

    // MARK: - Lifecycle

    private func setupTerminal() {
        terminalView.processDelegate = self
        terminalView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        terminalView.getTerminal().silentLog = true

        // 应用主题颜色
        applyThemeColors()

        // 监听系统外观变化
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.applyThemeColors()
            }
        }

        // 监听编辑器主题变化
        NotificationCenter.default.addObserver(
            forName: .lumiThemeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let editorThemeId = notification.userInfo?["editorThemeId"] as? String else { return }
            self?.currentThemeId = editorThemeId
            self?.applyThemeColors()
        }

        // 启动 shell 进程（使用 Shell Integration）
        startShell()
    }

    /// 启动 shell 进程
    private func startShell() {
        let shell = ShellIntegration.autoDetectShell()
        let shellPath = shell.defaultPath

        var environment = buildEnvironment()

        do {
            let args = try ShellIntegration.setupIntegration(
                for: shell,
                environment: &environment,
                useLogin: true
            )

            terminalView.startProcess(
                executable: shellPath,
                args: args,
                environment: environment,
                execName: shell.rawValue,
                currentDirectory: initialWorkingDirectory
            )
            isConnected = true
        } catch {
            // Shell Integration 失败时 fallback 到普通启动
            terminalView.startProcess(
                executable: shellPath,
                args: ["-l", "-i"],
                environment: buildEnvironment(),
                execName: shell.rawValue,
                currentDirectory: initialWorkingDirectory
            )
            isConnected = true
        }
    }

    /// 构建环境变量
    private func buildEnvironment() -> [String] {
        var env = Terminal.getEnvironmentVariables()
        env.append("TERM_PROGRAM=Lumi_Terminal")
        env.append("TERM=xterm-256color")
        env.append("LANG=en_US.UTF-8")
        // 补充常用 PATH
        env.append("PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin")
        return env
    }

    /// 应用主题颜色到终端
    private func applyThemeColors() {
        let colors = TerminalThemeAdapter.colors(for: currentThemeId)
        TerminalThemeAdapter.apply(colors, to: terminalView)
    }

    func terminate() {
        // 向整个进程组发送 SIGTERM，确保 shell 及其所有子进程（如 pnpm dev 启动的 node）都被清理
        if let process = terminalView.process, process.shellPid > 0 {
            // forkpty 创建的 shell 会成为新会话的领导者，其 PID 即为进程组 PGID
            let pgid = pid_t(process.shellPid)
            killpg(pgid, SIGTERM)

            // 给进程组一点时间优雅退出，之后强制 SIGKILL
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [pid = process.shellPid] in
                // 检查进程是否还在运行，避免向已回收的 PID 发信号
                if kill(pid, 0) == 0 {
                    killpg(pid, SIGKILL)
                }
            }
        }

        terminalView.terminate()
        isConnected = false
    }
}

// MARK: - LocalProcessTerminalViewDelegate

extension TerminalSession: LocalProcessTerminalViewDelegate {
    nonisolated func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    nonisolated func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        Task { @MainActor [weak self] in
            self?.title = title.isEmpty ? "Terminal" : title
        }
    }

    nonisolated func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    nonisolated func processTerminated(source: TerminalView, exitCode: Int32?) {
        Task { @MainActor [weak self] in
            self?.isConnected = false
        }
    }
}
