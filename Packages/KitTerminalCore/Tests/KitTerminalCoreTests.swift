import AppKit
import Foundation
import Testing
@testable import KitTerminalCore

@Suite("KitTerminalCore Tests")
struct KitTerminalCoreTests {

    @Test("ShellIntegration autoDetectShell")
    func shellIntegrationAutoDetect() {
        let shell = ShellIntegration.autoDetectShell()
        #expect(shell == .zsh || shell == .bash)
    }

    @Test("ShellIntegration Shell defaultPath")
    func shellDefaultPath() {
        #expect(ShellIntegration.Shell.zsh.defaultPath == "/bin/zsh")
        #expect(ShellIntegration.Shell.bash.defaultPath == "/bin/bash")
    }

    @Test("TerminalThemeAdapter defaultColors")
    func themeAdapterDefaultColors() {
        let darkColors = TerminalThemeAdapter.defaultColors(isDark: true)
        #expect(darkColors.ansiColors.count == 16)

        let lightColors = TerminalThemeAdapter.defaultColors(isDark: false)
        #expect(lightColors.ansiColors.count == 16)
    }

    @Test("TerminalThemeAdapter colors for known themes")
    func themeAdapterKnownThemes() {
        let themes = [
            "xcode-dark", "xcode-light", "midnight",
            "solarized-dark", "solarized-light", "high-contrast",
            "dracula", "monokai", "one-dark", "github-dark", "nord"
        ]

        for themeId in themes {
            let colors = TerminalThemeAdapter.colors(for: themeId)
            #expect(colors.ansiColors.count == 16)
        }
    }

    @Test("TerminalThemeAdapter unknown theme falls back to dark defaults")
    func themeAdapterUnknownThemeFallsBack() {
        let fallback = TerminalThemeAdapter.colors(for: "definitely-not-a-theme")
        let darkDefault = TerminalThemeAdapter.defaultColors(isDark: true)

        #expect(fallback.ansiColors.count == 16)
        #expect(fallback.ansiColors == darkDefault.ansiColors)
    }

    @MainActor
    @Test("TerminalTabsViewModel initialization")
    func tabsViewModelInit() {
        let viewModel = TerminalTabsViewModel(themeIdProvider: { "xcode-dark" })
        #expect(viewModel.sessions.isEmpty)
        #expect(viewModel.selectedSessionId == nil)
    }

    @MainActor
    @Test("切回较早会话后只有该会话可接收输入（回归 #1018）")
    func onlySelectedSessionIsHitTestable() {
        let viewModel = TerminalTabsViewModel(themeIdProvider: { "xcode-dark" })
        let early = UUID()
        let later = UUID()

        // 先选中后创建的 later，再切回较早的 early；数组顺序不变。
        viewModel.selectedSessionId = later
        viewModel.selectSession(early)

        let earlyPresentation = viewModel.presentation(for: early)
        let laterPresentation = viewModel.presentation(for: later)

        #expect(earlyPresentation.isSelected)
        #expect(earlyPresentation.opacity == 1)
        #expect(earlyPresentation.allowsHitTesting)
        #expect(laterPresentation.opacity == 0)
        #expect(!laterPresentation.allowsHitTesting)
        #expect(earlyPresentation.zIndex > laterPresentation.zIndex)
    }

    @MainActor
    @Test("TerminalSession initialization with theme")
    func sessionInitWithTheme() async {
        let session = TerminalSession(
            workingDirectory: nil,
            themeId: "xcode-dark",
            themeIdProvider: { "xcode-dark" }
        )
        #expect(session.title == "Terminal")

        // 等待 shell 启动
        try? await Task.sleep(for: .seconds(1))

        // 清理
        session.terminate()
    }

    /// 回归 #174：工作目录不存在时不得静默继承 Lumi 当前目录启动 shell，
    /// 会话必须保持未连接且不创建进程。
    @MainActor
    @Test("无效工作目录不得启动 shell 且保持未连接（回归 #174）")
    func invalidWorkingDirectoryDoesNotStartShell() {
        let missing = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lumi-missing-\(UUID().uuidString)").path
        let session = TerminalSession(workingDirectory: missing, themeIdProvider: { "xcode-dark" })
        session.terminalView.frame = NSRect(x: 0, y: 0, width: 80, height: 24)

        session.startIfNeeded()

        #expect(session.isConnected == false)
        #expect(session.terminalView.process.running == false)
        #expect(session.terminalView.process.shellPid == 0)
        #expect(session.startupError != nil)
        session.terminate()
    }

    /// 回归 #174：不存在的工作目录必须被校验拒绝。
    @Test("不存在的工作目录被拒绝（回归 #174）")
    func workingDirectoryValidatorRejectsMissingPath() {
        let missing = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lumi-missing-\(UUID().uuidString)").path
        #expect(throws: TerminalWorkingDirectory.Error.self) {
            try TerminalWorkingDirectory.validate(missing)
        }
    }

    /// 回归 #174：普通文件不是目录，必须被校验拒绝。
    @Test("普通文件不是目录被拒绝（回归 #174）")
    func workingDirectoryValidatorRejectsRegularFile() throws {
        let file = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lumi-file-\(UUID().uuidString)")
        try Data("x".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        #expect(throws: TerminalWorkingDirectory.Error.self) {
            try TerminalWorkingDirectory.validate(file.path)
        }
    }

    /// 回归 #174：无搜索权限的目录不可进入，必须被校验拒绝。
    @Test("无搜索权限的目录被拒绝（回归 #174）", .enabled(if: geteuid() != 0))
    func workingDirectoryValidatorRejectsInaccessibleDirectory() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lumi-noperm-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: dir.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
            try? FileManager.default.removeItem(at: dir)
        }

        #expect(throws: TerminalWorkingDirectory.Error.self) {
            try TerminalWorkingDirectory.validate(dir.path)
        }
    }

    /// 回归 #174：nil/空串继承当前目录，有效目录通过校验。
    @Test("nil/空串/有效目录均通过校验（回归 #174）")
    func workingDirectoryValidatorAcceptsValidInput() throws {
        try TerminalWorkingDirectory.validate(nil)
        try TerminalWorkingDirectory.validate("")

        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lumi-valid-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try TerminalWorkingDirectory.validate(dir.path)
    }
}