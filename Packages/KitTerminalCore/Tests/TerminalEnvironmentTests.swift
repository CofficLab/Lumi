import Testing
import Foundation
@testable import KitTerminalCore

/// 回归 #500：TerminalSession.buildEnvironment 只用 SwiftTerm 的允许列表，
/// 既不导出 SHELL 也不继承用户 ZDOTDIR，导致 `printenv SHELL` 失败、自定义
/// .zshrc 不加载，且集成脚本因数组里没有 ZDOTDIR 而回退到家目录。修复后
/// makeEnvironment 须补充所选 shell 的 SHELL、继承非空 ZDOTDIR，并保留 base。
struct TerminalEnvironmentTests {

    @Test("环境导出所选 shell 的 SHELL")
    func environmentExportsSelectedShell() {
        let env = ShellIntegration.makeEnvironment(base: [], shellPath: "/bin/zsh", parentEnvironment: [:])
        #expect(env.contains("SHELL=/bin/zsh"))
    }

    @Test("环境继承用户自定义 ZDOTDIR")
    func environmentInheritsCustomZdotdir() {
        let env = ShellIntegration.makeEnvironment(
            base: [], shellPath: "/bin/zsh", parentEnvironment: ["ZDOTDIR": "/tmp/custom-zsh"]
        )
        #expect(env.contains("ZDOTDIR=/tmp/custom-zsh"))
    }

    @Test("父进程未设置 ZDOTDIR 时不写入该项")
    func environmentOmitsZdotdirWhenUnset() {
        let env = ShellIntegration.makeEnvironment(base: [], shellPath: "/bin/zsh", parentEnvironment: [:])
        #expect(!env.contains { $0.hasPrefix("ZDOTDIR=") })
    }

    @Test("父进程 ZDOTDIR 为空串时不写入该项")
    func environmentOmitsZdotdirWhenEmpty() {
        let env = ShellIntegration.makeEnvironment(
            base: [], shellPath: "/bin/zsh", parentEnvironment: ["ZDOTDIR": ""]
        )
        #expect(!env.contains { $0.hasPrefix("ZDOTDIR=") })
    }

    @Test("环境保留 base 与 TERM/LANG/PATH 等基础项")
    func environmentKeepsBaseAndTermVars() {
        let env = ShellIntegration.makeEnvironment(
            base: ["HOME=/Users/tester"], shellPath: "/bin/bash", parentEnvironment: [:]
        )
        #expect(env.contains("HOME=/Users/tester"))
        #expect(env.contains("TERM_PROGRAM=Lumi_Terminal"))
        #expect(env.contains("TERM=xterm-256color"))
        #expect(env.contains("LANG=en_US.UTF-8"))
        #expect(env.contains("SHELL=/bin/bash"))
        #expect(env.contains { $0.hasPrefix("PATH=") })
    }

    @Test("集成脚本从环境恢复用户 ZDOTDIR 而非回退家目录")
    func integrationRecoversCustomZdotdir() async throws {
        let base = ShellIntegration.makeEnvironment(
            base: [], shellPath: "/bin/zsh", parentEnvironment: ["ZDOTDIR": "/tmp/custom-zsh"]
        )
        let setup = try await ShellIntegration.setupIntegration(for: .zsh, baseEnvironment: base)
        #expect(setup.additionalEnvironment.contains("USER_ZDOTDIR=/tmp/custom-zsh"))
    }
}