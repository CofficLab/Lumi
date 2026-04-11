import Foundation
import SwiftUI
import AppKit
import SwiftTerm

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
    /// 当前编辑器主题名称（用于终端颜色同步）
    private var currentThemeName: LumiEditorThemeAdapter.PresetTheme

    init(workingDirectory: String? = nil) {
        self.initialWorkingDirectory = workingDirectory
        self.terminalView = LumiTerminalView(frame: .zero)

        // 读取当前编辑器主题
        if let themeRaw = LumiEditorConfigStore.loadString(forKey: LumiEditorConfigStore.themeNameKey),
           let preset = LumiEditorThemeAdapter.PresetTheme(rawValue: themeRaw) {
            self.currentThemeName = preset
        } else {
            self.currentThemeName = .xcodeDark
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
            forName: .lumiEditorThemeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let themeName = notification.userInfo?["theme"] as? LumiEditorThemeAdapter.PresetTheme else { return }
            self?.currentThemeName = themeName
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
        let colors = TerminalThemeAdapter.colors(for: currentThemeName)
        TerminalThemeAdapter.apply(colors, to: terminalView)
    }

    func terminate() {
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

// MARK: - Notification Name

extension Notification.Name {
    /// 编辑器主题变更通知
    static let lumiEditorThemeDidChange = Notification.Name("lumiEditorThemeDidChange")
}
