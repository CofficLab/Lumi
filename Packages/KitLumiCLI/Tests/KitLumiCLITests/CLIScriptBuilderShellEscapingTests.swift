import Foundation
import Testing
@testable import KitLumiCLI

/// #142 回归：安装时记录的 App 路径会被嵌入 `lumi` 脚本的 `find_lumi_app`。
/// macOS 允许路径含 `$`、反引号、`"`、`\`、空格、非 ASCII 等合法字符，
/// 旧实现把路径直接插进 shell 双引号，导致这些字符被展开/改写，解析到错误位置。
///
/// 这些测试**真实执行** /bin/sh：创建含特殊字符的真实目录，生成脚本，抽出
/// `find_lumi_app` 函数运行，断言它原样返回该目录——而不是仅断言生成字符串包含路径。
@Suite("CLIScriptBuilder shell 转义")
struct CLIScriptBuilderShellEscapingTests {

    /// 从完整脚本中抽出 `find_lumi_app() { ... }`（顶层函数，体内无 `}`）。
    private func findLumiAppFunction(in script: String) -> String {
        guard let start = script.range(of: "find_lumi_app() {"),
              let end = script.range(of: "\n}\n", range: start.upperBound..<script.endIndex)
        else { return "" }
        return String(script[start.lowerBound..<end.upperBound])
    }

    /// 创建名为 `name` 的真实 App 目录，把它作为安装路径嵌入脚本并真实执行
    /// `find_lumi_app`，返回 (实际解析结果, 期望路径)。
    private func resolveEmbeddedAppPath(named name: String) throws -> (resolved: String, expected: String) {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("kitlumicli-esc-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        let appDir = parent.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        let script = CLIScriptBuilder.scriptContents(appPath: appDir.path)
        let function = findLumiAppFunction(in: script)
        let harness = function + "\nfind_lumi_app\n"
        let harnessURL = parent.appendingPathComponent("harness.sh")
        try harness.write(to: harnessURL, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [harnessURL.path]
        var env = ProcessInfo.processInfo.environment
        env.removeValue(forKey: "LUMI_APP")
        process.environment = env
        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let resolved = String(data: data, encoding: .utf8) ?? ""
        return (resolved, appDir.path)
    }

    @Test("含 $ 的安装路径必须原样解析，不得被 shell 展开")
    func dollarSignPathResolvesVerbatim() throws {
        let r = try resolveEmbeddedAppPath(named: "Dollar$LUMI_SUFFIX.app")
        #expect(r.resolved == r.expected)
    }

    @Test("含反引号的安装路径必须原样解析，不得触发命令替换")
    func backtickPathResolvesVerbatim() throws {
        let r = try resolveEmbeddedAppPath(named: "Backtick`lumi_nx_cmd.app")
        #expect(r.resolved == r.expected)
    }

    @Test("含双引号的安装路径必须原样解析，不得破坏引号边界")
    func doubleQuotePathResolvesVerbatim() throws {
        let r = try resolveEmbeddedAppPath(named: "Quote\"name.app")
        #expect(r.resolved == r.expected)
    }

    @Test("含反斜杠的安装路径必须原样解析，不得被转义改写")
    func backslashPathResolvesVerbatim() throws {
        let r = try resolveEmbeddedAppPath(named: "Two\\\\back.app")
        #expect(r.resolved == r.expected)
    }

    @Test("含单引号的安装路径原样解析（单引号转义回归）")
    func singleQuotePathResolvesVerbatim() throws {
        let r = try resolveEmbeddedAppPath(named: "Single'quote.app")
        #expect(r.resolved == r.expected)
    }

    @Test("含空格的安装路径原样解析")
    func spacePathResolvesVerbatim() throws {
        let r = try resolveEmbeddedAppPath(named: "Space name.app")
        #expect(r.resolved == r.expected)
    }

    @Test("含非 ASCII 字符的安装路径原样解析")
    func nonASCIIPathResolvesVerbatim() throws {
        let r = try resolveEmbeddedAppPath(named: "中文应用.app")
        #expect(r.resolved == r.expected)
    }

    @Test("含全部特殊字符的安装路径必须原样解析，不得被 shell 改写")
    func combinedSpecialCharsPathResolvesVerbatim() throws {
        let r = try resolveEmbeddedAppPath(named: "Mix $v `lumi_nx` \"q\" \\w 's' 中文.app")
        #expect(r.resolved == r.expected)
    }
}
