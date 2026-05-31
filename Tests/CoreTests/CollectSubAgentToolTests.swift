#if canImport(XCTest)
import XCTest
@testable import Lumi

final class CollectSubAgentToolTests: XCTestCase {
    func testNormalizesTimeout() {
        XCTAssertEqual(CollectSubAgentTool.normalizedTimeout(nil), 120)
        XCTAssertEqual(CollectSubAgentTool.normalizedTimeout(-10), 1)
        XCTAssertEqual(CollectSubAgentTool.normalizedTimeout(0), 1)
        XCTAssertEqual(CollectSubAgentTool.normalizedTimeout(30), 30)
        XCTAssertEqual(CollectSubAgentTool.normalizedTimeout(30.0), 30)
        XCTAssertEqual(CollectSubAgentTool.normalizedTimeout("30"), 30)
        XCTAssertEqual(CollectSubAgentTool.normalizedTimeout(10_000), 3600)
        XCTAssertEqual(CollectSubAgentTool.normalizedTimeout("not-a-number"), 120)
    }
}
#endif
