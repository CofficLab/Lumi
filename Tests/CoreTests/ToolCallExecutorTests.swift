#if canImport(XCTest)
import XCTest
import AgentToolKit
@testable import Lumi

final class ToolCallExecutorTests: XCTestCase {
    func testToolErrorOutputDetectsCommonToolErrorPrefixes() {
        XCTAssertTrue(ToolCallExecutor.isToolErrorOutput("Error: File does not exist"))
        XCTAssertTrue(ToolCallExecutor.isToolErrorOutput(" \n错误：文件不存在"))
    }

    func testToolErrorOutputDoesNotTreatOrdinaryTextAsError() {
        XCTAssertFalse(ToolCallExecutor.isToolErrorOutput("Completed without errors"))
        XCTAssertFalse(ToolCallExecutor.isToolErrorOutput("stderr: error count 0"))
    }

    func testUserRejectedToolResultIsMarkedAsError() {
        let result = ToolCallExecutor.userRejectedToolResult()

        XCTAssertEqual(result.content, "用户拒绝执行此工具")
        XCTAssertTrue(result.isError)
    }

    func testCancelledToolResultIsMarkedAsError() {
        let result = ToolCallExecutor.cancelledToolResult(duration: 1.25)

        XCTAssertEqual(result.content, "执行已取消")
        XCTAssertTrue(result.isError)
        XCTAssertEqual(result.duration, 1.25)
    }

    func testMarkUnfinishedToolCallsCancelledDoesNotLeavePendingResults() {
        var calls = [
            ToolCall(id: "first", name: "read_file", arguments: "{}"),
            ToolCall(id: "second", name: "write_file", arguments: "{}"),
            ToolCall(
                id: "third",
                name: "list_files",
                arguments: "{}",
                result: ToolCallResult(content: "already completed")
            ),
        ]

        ToolCallExecutor.markUnfinishedToolCallsCancelled(&calls, startingAt: 1)

        XCTAssertNil(calls[0].result)
        XCTAssertEqual(calls[1].result?.content, "执行已取消")
        XCTAssertEqual(calls[1].result?.isError, true)
        XCTAssertEqual(calls[2].result?.content, "already completed")
        XCTAssertEqual(calls[2].result?.isError, false)
    }
}
#endif
