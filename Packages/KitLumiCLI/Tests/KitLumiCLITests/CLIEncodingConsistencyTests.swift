import Foundation
import Testing
@testable import KitLumiCLI

/// CLI 脚本与 App 端 URL 编解码的一致性测试。
///
/// 脚本用 perl 做百分号编码，App 用 `URLComponents` 解析；
/// 两者必须对同一路径产出可互相还原的结果，否则含特殊字符的目录
/// 在传输中会损坏。
@Suite("CLI 编解码一致性")
struct CLIEncodingConsistencyTests {

    /// 覆盖路径中可能出现的各类字符。
    private let samplePaths = [
        "/tmp/plain",
        "/tmp/with space",
        "/tmp/中文目录",
        "/tmp/with#hash",
        "/tmp/with&ampersand",
        "/tmp/with+plus",
        "/tmp/with'quote",
        "/tmp/with(paren)",
        "/tmp/with=equals:colon@at",
        "/tmp/100%percent",
        "/tmp/with~tilde",
        "/tmp/with-underscore.dot",
        "/tmp/with\"double\"quote",
        "/tmp/with\\backslash",
        "/tmp/with;semi&amp",
    ]

    /// 脚本的百分号编码：与 `CLIScriptBuilder` 中脚本内的 perl 调用一致。
    private func perlEncode(_ path: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [
            "-0777",
            "-ne",
            "s/([^A-Za-z0-9._~-])/sprintf(\"%%%02X\", ord($1))/ge; print",
        ]
        let outputPipe = Pipe()
        let inputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardInput = inputPipe
        try process.run()

        inputPipe.fileHandleForWriting.write(Data(path.utf8))
        inputPipe.fileHandleForWriting.closeFile()
        let output = String(
            data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        process.waitUntilExit()
        return output
    }

    /// App 端解析：从 `lumi://finder/open-project?path=...` 还原出目录路径。
    private func appResolve(_ urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == "path" }?
            .value
    }

    @Test("脚本编码可被 App 还原")
    func scriptEncodingIsReversibleByApp() throws {
        for path in samplePaths {
            let encoded = try perlEncode(path)
            let restored = appResolve("lumi://finder/open-project?path=\(encoded)")
            #expect(
                restored == path,
                "path \(path) was encoded as \(encoded) but restored to \(restored ?? "<nil>")"
            )
        }
    }

    @Test("App 自身构造的 URL 可被自己解析回来")
    func appEncodingIsReversibleByApp() throws {
        for path in samplePaths {
            var components = URLComponents()
            components.scheme = "lumi"
            components.host = "finder"
            components.path = "/open-project"
            components.queryItems = [URLQueryItem(name: "path", value: path)]
            guard let url = components.url else {
                Issue.record("failed to build URL for \(path)")
                continue
            }
            #expect(appResolve(url.absoluteString) == path)
        }
    }

    @Test("脚本产出的编码是合法的 URL query")
    func scriptEncodingIsAcceptedByURLComponents() throws {
        for path in samplePaths {
            let encoded = try perlEncode(path)
            #expect(
                URL(string: "lumi://finder/open-project?path=\(encoded)") != nil,
                "script produced an unparsable URL for \(path): \(encoded)"
            )
        }
    }

    @Test("脚本中的 perl 编码表达式与测试中的一致")
    func scriptUsesSameEncoderAsTest() throws {
        let script = CLIScriptBuilder.scriptContents()
        #expect(
            script.contains("s/([^A-Za-z0-9._~-])/sprintf(\"%%%02X\", ord($1))/ge"),
            "脚本的编码表达式变化时必须同步更新本测试"
        )
        #expect(script.contains("perl -0777 -ne"), "脚本必须用 slurp 模式整串编码（#143）")
        #expect(!script.contains("-ne 'chomp"), "脚本不得用行输入模式 + chomp，否则会丢弃目录名中的换行（#143）")

        // 脚本里的表达式与测试里的表达式必须产出相同结果。
        let path = "/tmp/中文 目录#1"
        let expected = try perlEncode(path)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [
            "-0777",
            "-ne",
            "s/([^A-Za-z0-9._~-])/sprintf(\"%%%02X\", ord($1))/ge; print",
        ]
        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        try process.run()
        input.fileHandleForWriting.write(Data(path.utf8))
        input.fileHandleForWriting.closeFile()
        let actual = String(
            data: output.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        process.waitUntilExit()

        #expect(actual == expected)
    }
}
