import Foundation
import Testing
@testable import PluginMCP

/// MCP 参数编辑框的拼接/拆分必须可逆，含空格的单个参数不得被拆坏（#534）。
///
/// 这些用例锁定 `MCPArgumentsCodec` 的纯逻辑：shell 风格引号、转义、空参数、
/// 以及核心不变量 `parse(join(args)) == args`。视图侧 populate/saveAndConnect
/// 直接调用这两个函数，故此处即覆盖生产往返链路。
struct MCPArgumentsCodecTests {
    @Test
    func roundTripPreservesArgumentWithSpaces() {
        let arguments = ["--root", "/tmp/My Project"]
        #expect(MCPArgumentsCodec.parse(MCPArgumentsCodec.join(arguments)) == arguments)
    }

    @Test
    func joinQuotesArgumentWithSpaces() {
        #expect(MCPArgumentsCodec.join(["--root", "/tmp/My Project"]) == "--root \"/tmp/My Project\"")
    }

    @Test
    func parseDoubleQuotedInputKeepsSpaces() {
        #expect(MCPArgumentsCodec.parse("--root \"/tmp/My Project\"") == ["--root", "/tmp/My Project"])
    }

    @Test
    func parseSingleQuotedInputKeepsSpaces() {
        #expect(MCPArgumentsCodec.parse("--root '/tmp/My Project'") == ["--root", "/tmp/My Project"])
    }

    @Test
    func plainArgumentsAreUnchanged() {
        let arguments = ["--root", "/tmp/proj", "--verbose"]
        #expect(MCPArgumentsCodec.join(arguments) == "--root /tmp/proj --verbose")
        #expect(MCPArgumentsCodec.parse("--root /tmp/proj --verbose") == arguments)
    }

    @Test
    func emptyArgumentRoundTrips() {
        #expect(MCPArgumentsCodec.join([""]) == "\"\"")
        #expect(MCPArgumentsCodec.parse("\"\"") == [""])
        #expect(MCPArgumentsCodec.parse(MCPArgumentsCodec.join([""])) == [""])
    }

    @Test
    func embeddedDoubleQuoteRoundTrips() {
        let arguments = ["a\"b"]
        #expect(MCPArgumentsCodec.parse(MCPArgumentsCodec.join(arguments)) == arguments)
    }

    @Test
    func embeddedBackslashRoundTrips() {
        let arguments = ["a\\b"]
        #expect(MCPArgumentsCodec.parse(MCPArgumentsCodec.join(arguments)) == arguments)
    }

    @Test
    func embeddedSingleQuoteRoundTrips() {
        let arguments = ["it's"]
        #expect(MCPArgumentsCodec.parse(MCPArgumentsCodec.join(arguments)) == arguments)
    }

    @Test
    func whitespaceInsideArgumentIsPreserved() {
        let arguments = ["a\tb", "c\nd", "e f"]
        #expect(MCPArgumentsCodec.parse(MCPArgumentsCodec.join(arguments)) == arguments)
    }

    @Test
    func emptyAndWhitespaceTextYieldNoArguments() {
        #expect(MCPArgumentsCodec.parse("") == [])
        #expect(MCPArgumentsCodec.parse("   ") == [])
        #expect(MCPArgumentsCodec.parse("\n\t ") == [])
    }

    @Test
    func emptyArrayJoinsToEmptyText() {
        #expect(MCPArgumentsCodec.join([]) == "")
    }

    @Test
    func adjacentQuotedSegmentsConcatenate() {
        #expect(MCPArgumentsCodec.parse("a\"b\"c") == ["abc"])
        #expect(MCPArgumentsCodec.parse("'a'b\"c\"") == ["abc"])
    }

    @Test
    func backslashEscapesSpaceOutsideQuotes() {
        #expect(MCPArgumentsCodec.parse("a\\ b") == ["a b"])
    }

    @Test
    func roundTripHoldsForVariedCorpus() {
        let corpus: [[String]] = [
            [],
            [""],
            ["", ""],
            ["simple"],
            ["--root", "/tmp/My Project"],
            ["a\"b", "c\\d", "e'f"],
            ["tab\there", "new\nline", "space here"],
            ["\"quoted\"", "'single'", "\\backslash"],
            ["mix'\"\\ ", "  ", "x"],
            ["日本語 のパス", "emoji😀 arg"],
        ]
        for arguments in corpus {
            #expect(MCPArgumentsCodec.parse(MCPArgumentsCodec.join(arguments)) == arguments)
        }
    }
}