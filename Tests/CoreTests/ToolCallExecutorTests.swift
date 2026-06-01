#if canImport(XCTest)
import XCTest
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
}
#endif
