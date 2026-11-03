import Foundation
import Testing
@testable import KitLumiCLI

/// `CLIScriptBuilder` 生成的脚本内容测试。
@Suite("CLIScriptBuilder")
struct CLIScriptBuilderTests {

    @Test("脚本以 shebang 开头且带执行权限语义")
    func scriptStartsWithShebang() {
        let script = CLIScriptBuilder.scriptContents()
        #expect(script.hasPrefix("#!/bin/sh\n"))
    }

    @Test("命令名默认为 lumi")
    func defaultCommandNameIsLumi() {
        #expect(CLIScriptBuilder.commandName == "lumi")
        let script = CLIScriptBuilder.scriptContents()
        #expect(script.contains("# lumi — 在 Lumi 中打开当前目录"))
    }

    @Test("脚本复用 Lumi 既有的 open-project 协议")
    func usesExistingOpenProjectProtocol() {
        let script = CLIScriptBuilder.scriptContents()
        #expect(script.contains("://finder/open-project?path="))
    }

    @Test("脚本显式用 open -g -a 指定 App")
    func usesExplicitAppRouting() {
        // 同一 scheme 可能被 Release / Debug 两个构建注册，交给系统路由会
        // 投递到不确定的实例，因此必须显式 -a。
        let script = CLIScriptBuilder.scriptContents()
        #expect(script.contains("/usr/bin/open -g -a \"$APP_PATH\""))
    }

    @Test("脚本不修改用户的 shell 配置")
    func doesNotModifyShellConfiguration() {
        let script = CLIScriptBuilder.scriptContents()
        #expect(!script.contains(".zshrc"))
        #expect(!script.contains(".bashrc"))
        #expect(!script.contains(".zprofile"))
    }

    @Test("脚本优先使用 LUMI_APP 环境变量")
    func honorsAppPathEnvironmentVariable() {
        let script = CLIScriptBuilder.scriptContents()
        #expect(script.contains("LUMI_APP"))
        #expect(script.contains("if [ -n \"${LUMI_APP:-}\" ]; then"))
    }

    @Test("安装时记录的 App 路径被写入脚本")
    func embedsRecordedAppPath() {
        let script = CLIScriptBuilder.scriptContents(appPath: "/Applications/Lumi.app")
        #expect(script.contains("\"/Applications/Lumi.app\" \\"))
    }

    @Test("未提供 App 路径时使用常见安装位置兜底")
    func fallsBackToCommonInstallLocations() {
        let script = CLIScriptBuilder.scriptContents()
        #expect(script.contains("\"/Applications/Lumi.app\" \\"))
        #expect(script.contains("\"$HOME/Applications/Lumi.app\""))
    }

    @Test("scheme 从 App 的 Info.plist 读取并有兜底值")
    func readsSchemeFromInfoPlist() {
        let script = CLIScriptBuilder.scriptContents(urlScheme: "lumi-debug")
        #expect(script.contains("LumiURLScheme"))
        #expect(script.contains("/usr/libexec/PlistBuddy"))
        #expect(script.contains("URL_SCHEME=\"lumi-debug\""))
    }

    @Test("生成的脚本通过 shell 语法检查")
    func generatedScriptIsValidShell() throws {
        let script = CLIScriptBuilder.scriptContents(appPath: "/Applications/Lumi.app")
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kitlumicli-script-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let scriptURL = directory.appendingPathComponent("lumi")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-n", scriptURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus == 0, "生成的脚本存在 shell 语法错误")
    }
}
