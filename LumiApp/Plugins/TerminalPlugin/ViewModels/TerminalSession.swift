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
        terminalView.nativeBackgroundColor = NSColor.black
        terminalView.nativeForegroundColor = NSColor.textColor
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
