import Testing
import Foundation
@testable import KitTerminalCore

/// 回归 #346：bash 登录模式（-l）会忽略 --init-file，注入脚本完全不执行，
/// 标题集成失效。修复后 bash 不再叠加 -l，登录启动链由脚本自身在
/// LUMI_SHELL_LOGIN 分支重放；zsh 继续走 ZDOTDIR 方案并保留 -l。
struct TerminalBashLoginIntegrationTests {

    @Test("bash 参数不得叠加 -l（回归 #346）")
    func bashArgsOmitLoginFlag() throws {
        var env: [String] = []
        let args = try ShellIntegration.setupIntegration(
            for: .bash,
            environment: &env,
            useLogin: true
        )
        #expect(args.contains("--init-file"))
        #expect(args.contains("-i"))
        #expect(!args.contains("-l"))
        #expect(env.contains("LUMI_SHELL_LOGIN=1"))
    }

    @Test("zsh 登录模式仍保留 -l")
    func zshArgsKeepLoginFlag() throws {
        var env: [String] = []
        let args = try ShellIntegration.setupIntegration(
            for: .zsh,
            environment: &env,
            useLogin: true
        )
        #expect(args.contains("-l"))
        #expect(args.contains("-i"))
    }

    @Test("登录 bash 启动时执行注入脚本并输出标题序列（回归 #346）")
    @MainActor
    func loginBashRunsIntegrationScript() throws {
        var env: [String] = []
        let args = try ShellIntegration.setupIntegration(
            for: .bash,
            environment: &env,
            useLogin: true
        )

        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/bin/bash")
        var environment: [String: String] = [
            "HOME": NSTemporaryDirectory(),
            "PATH": "/usr/bin:/bin",
        ]
        for entry in env {
            let parts = entry.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                environment[String(parts[0])] = String(parts[1])
            }
        }
        shell.environment = environment
        shell.arguments = args

        let input = Pipe()
        let output = Pipe()
        shell.standardInput = input
        shell.standardOutput = output
        shell.standardError = Pipe()
        try shell.run()

        let handle = input.fileHandleForWriting
        handle.write("printf LUMI_MARK_346\nexit\n".data(using: .utf8)!)
        handle.closeFile()
        shell.waitUntilExit()

        let data = output.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        #expect(text.contains("]0;printf LUMI_MARK_346\u{07}"))
        #expect(text.contains("]0;bash\u{07}"))
    }
}
