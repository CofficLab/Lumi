import Foundation
import Testing
@testable import KitLumiCLI

/// #143 回归：脚本的 `urlencode` 必须对完整路径逐字节编码，把换行保留为 `%0A`、
/// 回车保留为 `%0D`，而不是用 perl 行输入模式 + chomp 把目录名里的换行丢弃。
///
/// 这些测试**真实执行** /bin/sh：从生成的脚本里抽出 `urlencode` 函数，把含特殊
/// 字符的路径作为 argv 传入运行，断言产出的百分号编码与 App 端 `URLComponents`
/// 还原结果一致——而不是仅断言生成字符串包含某个表达式。
@Suite("CLIScriptBuilder URL 编码")
struct CLIScriptBuilderURLEncodingTests {

    /// 从脚本中抽出 `urlencode() { ... }` 函数体。
    private func urlencodeFunction(in script: String) -> String {
        guard let start = script.range(of: "urlencode() {") else { return "" }
        guard let end = script.range(of: "\n}", range: start.upperBound..<script.endIndex) else { return "" }
        return String(script[start.lowerBound..<end.upperBound])
    }

    /// 真实运行脚本里的 `urlencode`，返回百分号编码结果。
    private func scriptEncode(_ path: String) throws -> String {
        let script = CLIScriptBuilder.scriptContents()
        let function = urlencodeFunction(in: script)
        #expect(!function.isEmpty, "未能从脚本中抽出 urlencode 函数")

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kitlumicli-enc-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let harness = directory.appendingPathComponent("harness.sh")
        try (function + "\nurlencode \"$1\"\n").write(to: harness, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [harness.path, path]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// App 端解析：从 `lumi://finder/open-project?path=...` 还原目录路径。
    private func appResolve(_ urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == "path" }?
            .value
    }

    @Test("含换行的目录名必须编码为 %0A，不得被 chomp 丢弃")
    func newlineInPathIsPreserved() throws {
        let encoded = try scriptEncode("/tmp/a\nb")
        #expect(encoded == "%2Ftmp%2Fa%0Ab", "换行被丢弃或改写：\(encoded)")
    }

    @Test("含回车的目录名必须编码为 %0D")
    func carriageReturnInPathIsPreserved() throws {
        let encoded = try scriptEncode("/tmp/a\rb")
        #expect(encoded == "%2Ftmp%2Fa%0Db", "回车被丢弃或改写：\(encoded)")
    }

    @Test("含 CRLF 的目录名必须编码为 %0D%0A，不得只保留回车")
    func crlfInPathIsPreserved() throws {
        let encoded = try scriptEncode("/tmp/a\r\nb")
        #expect(encoded == "%2Ftmp%2Fa%0D%0Ab", "CRLF 中的换行被丢弃：\(encoded)")
    }

    @Test("含换行的路径经脚本编码后可被 App 原样还原")
    func newlinePathRoundTripsThroughApp() throws {
        let path = "/tmp/a\nb"
        let encoded = try scriptEncode(path)
        #expect(appResolve("lumi://finder/open-project?path=\(encoded)") == path)
    }

    @Test("多字节字符与换行混合的路径编码后可被 App 原样还原")
    func multibyteWithNewlineRoundTrips() throws {
        let path = "/tmp/中文\n目录"
        let encoded = try scriptEncode(path)
        #expect(encoded.contains("%0A"), "多字节路径中的换行被丢弃：\(encoded)")
        #expect(appResolve("lumi://finder/open-project?path=\(encoded)") == path)
    }

    @Test("不含特殊字符的多字节路径编码保持不变（无回归）")
    func plainMultibytePathIsUnchanged() throws {
        let encoded = try scriptEncode("/tmp/中文目录")
        #expect(encoded == "%2Ftmp%2F%E4%B8%AD%E6%96%87%E7%9B%AE%E5%BD%95")
    }
}
