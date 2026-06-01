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
}
#endif
