import Foundation
import Testing
@testable import PluginProjectFileTree

/// 回归 #446：「在终端中打开」此前把路径直接拼进 `do script "cd '…'"`，
/// 路径含单引号会提前闭合 shell 引号，含双引号/反斜杠还会破坏 AppleScript 字符串。
/// 这里锁定两层转义（shell 单引号 + AppleScript 双引号）后任意合法 POSIX 路径都能还原。
@Suite("FileTreeFacade 终端命令转义")
struct FileTreeTerminalEscapingTests {

    @Test("普通路径只做单引号包裹")
    func plainPathIsSingleQuoted() {
        #expect(FileTreeFacade.terminalDoScriptArgument(forPath: "/tmp/plain") == "cd '/tmp/plain'")
    }

    @Test("双引号必须做 AppleScript 转义")
    func doubleQuoteIsAppleScriptEscaped() {
        let argument = FileTreeFacade.terminalDoScriptArgument(forPath: "/tmp/a\"b")
        #expect(argument.contains("\\\""), "双引号必须被转义，否则破坏 AppleScript 字符串")
    }

    @Test("反斜杠必须做 AppleScript 转义")
    func backslashIsAppleScriptEscaped() {
        let argument = FileTreeFacade.terminalDoScriptArgument(forPath: "/tmp/a\\b")
        #expect(argument.contains("\\\\"), "反斜杠必须被加倍，否则被 AppleScript 当作转义符吃掉")
    }

    @Test("任意合法路径经真实 shell 解析后原样还原", arguments: [
        "/tmp/plain",
        "/tmp/lumi-it's",
        "/tmp/a\"b",
        "/tmp/a\\b",
        "/tmp/with space",
        "/tmp/a\"b\\c'd",
        "/tmp/中文目录",
        "/tmp/new\nline",
    ])
    func shellRecoversOriginalPath(path: String) throws {
        let argument = FileTreeFacade.terminalDoScriptArgument(forPath: path)
        let shellCommand = Self.appleScriptUnescape(argument)
        // 把 cd 换成 printf 原样输出参数，交给真实 /bin/sh 解析单引号。
        let printfCommand = "printf '%s' " + shellCommand.dropFirst(3)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", printfCommand]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        #expect(output == path, "shell 解析后应原样取回路径")
    }

    /// 逆 AppleScript 双引号转义：逐个把 `\X` 还原成 `X`。
    private nonisolated static func appleScriptUnescape(_ string: String) -> String {
        var result = ""
        var iterator = string.makeIterator()
        while let char = iterator.next() {
            if char == "\\" {
                if let next = iterator.next() {
                    result.append(next)
                }
            } else {
                result.append(char)
            }
        }
        return result
    }
}