import XCTest
@testable import LLMKit

final class LLMToolNameSanitizerTests: XCTestCase {
    // MARK: - sanitize

    func testSanitizeKeepsValidNameUnchanged() {
        XCTAssertEqual(LLMToolNameSanitizer.sanitize("read_file"), "read_file")
        XCTAssertEqual(LLMToolNameSanitizer.sanitize("git_commit"), "git_commit")
        XCTAssertEqual(LLMToolNameSanitizer.sanitize("list-stories"), "list-stories")
        XCTAssertEqual(LLMToolNameSanitizer.sanitize("browser_agent"), "browser_agent")
    }

    func testSanitizeReplacesDotsWithUnderscore() {
        // Kimi 400 的直接触发场景：MCP 工具名带点号
        XCTAssertEqual(
            LLMToolNameSanitizer.sanitize("app-store-connect.list-apps"),
            "app-store-connect_list-apps"
        )
        XCTAssertEqual(
            LLMToolNameSanitizer.sanitize("app-store-connect.read-ci-workflow"),
            "app-store-connect_read-ci-workflow"
        )
    }

    func testSanitizeReplacesNonAsciiBytesWithUnderscore() {
        // 中文按 ASCII 字节级逐个替换（不能用 Character.isLetter 判定）
        // "工具" = 6 个 UTF-8 字节 → 6 个替换下划线；首字节非法 → 补 "tool_" 前缀
        // 前缀自带 1 个下划线，合计 "tool" + 7 个下划线
        XCTAssertEqual(LLMToolNameSanitizer.sanitize("工具"), "tool_______")
    }

    func testSanitizeEnsuresLeadingLetter() {
        // Kimi 要求 must start with a letter：数字/下划线/短横线开头都补前缀
        XCTAssertEqual(LLMToolNameSanitizer.sanitize("123abc"), "tool_123abc")
        XCTAssertEqual(LLMToolNameSanitizer.sanitize("_private"), "tool__private")
        XCTAssertEqual(LLMToolNameSanitizer.sanitize("-flag"), "tool_-flag")
    }

    func testSanitizeFallsBackForEmptyInput() {
        XCTAssertEqual(LLMToolNameSanitizer.sanitize(""), "tool")
    }

    // MARK: - reverseMap

    func testReverseMapMapsSanitizedNameToOriginal() {
        let tools = [
            MockSanitizerTool(name: "app-store-connect.list-apps"),
            MockSanitizerTool(name: "read_file"),
        ]
        let map = LLMToolNameSanitizer.reverseMap(for: tools)

        XCTAssertEqual(map["app-store-connect_list-apps"], "app-store-connect.list-apps")
        // 合法名字原样映射，不影响执行
        XCTAssertEqual(map["read_file"], "read_file")
    }

    func testReverseMapFirstRegistrationWinsOnCollision() {
        let tools = [
            MockSanitizerTool(name: "a.b"),
            MockSanitizerTool(name: "a_b"),
        ]
        let map = LLMToolNameSanitizer.reverseMap(for: tools)

        // 两者 sanitize 后都变成 a_b，先注册者（a.b）优先
        XCTAssertEqual(map["a_b"], "a.b")
        XCTAssertEqual(map.count, 1)
    }

    func testReverseMapEmptyTools() {
        XCTAssertTrue(LLMToolNameSanitizer.reverseMap(for: []).isEmpty)
    }
}

private struct MockSanitizerTool: LLMToolSchemaProviding {
    let name: String
    let toolDescription: String = ""
    let inputSchema: [String: Any] = [:]
}
