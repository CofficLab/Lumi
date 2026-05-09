import Testing
@testable import TerminalCoreKit

@Suite("TerminalCoreKit Tests")
struct TerminalCoreKitTests {

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

    @MainActor
    @Test("TerminalTabsViewModel initialization")
    func tabsViewModelInit() {
        let viewModel = TerminalTabsViewModel(themeIdProvider: { "xcode-dark" })
        #expect(viewModel.sessions.isEmpty)
        #expect(viewModel.selectedSessionId == nil)
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
}