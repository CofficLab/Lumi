import Foundation
import SwiftUI
import AppKit
import SwiftTerm

@MainActor
final class TerminalSession: ObservableObject, Identifiable {
    let id = UUID()
    @Published var title: String = "Terminal"
    @Published var isConnected: Bool = false

    /// SwiftTerm 原生终端视图（每个会话一个实例）
    let terminalView: LocalProcessTerminalView
    private let initialWorkingDirectory: String?
    /// KVO 观察系统外观变化
    private var appearanceObservation: NSKeyValueObservation?
    
    init(workingDirectory: String? = nil) {
        self.initialWorkingDirectory = workingDirectory
        self.terminalView = LocalProcessTerminalView(frame: .zero)
        setupTerminal()
    }
    
    // MARK: - Lifecycle

    private func setupTerminal() {
        terminalView.processDelegate = self
        terminalView.configureNativeColors()
        terminalView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        // 根据系统外观动态设置终端颜色
        applyColors()

        // 监听系统外观变化（KVO 观察 NSApp.effectiveAppearance）
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.applyColors()
            }
        }

        terminalView.startProcess(
            executable: "/bin/zsh",
            args: ["-f", "-i"],
            environment: [
                "TERM=xterm-256color",
                "LANG=en_US.UTF-8",
                "PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            ],
            currentDirectory: initialWorkingDirectory
        )
        isConnected = true
    }

    /// 根据当前系统外观设置终端的前景/背景色
    private func applyColors() {
        let isDark = NSApp.effectiveAppearance.bestMatch(
            from: [.darkAqua, .aqua]
        ) == .darkAqua

        terminalView.nativeBackgroundColor = isDark
            ? NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)  // 深色背景
            : NSColor.white                                                  // 白色背景
        terminalView.nativeForegroundColor = isDark
            ? NSColor(white: 0.92, alpha: 1.0)   // 浅色文字
            : NSColor(white: 0.12, alpha: 1.0)   // 深色文字
    }
    
    func terminate() {
        terminalView.terminate()
        isConnected = false
    }
}

extension TerminalSession: LocalProcessTerminalViewDelegate {
    // MARK: - LocalProcessTerminalViewDelegate

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
