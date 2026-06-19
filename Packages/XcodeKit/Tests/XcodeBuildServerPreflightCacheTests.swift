#if canImport(XCTest)
import XCTest
@testable import XcodeKit

final class XcodeBuildServerPreflightCacheTests: XCTestCase {
    func testCacheReturnsSameInstanceWithinTTL() {
        XcodeBuildServerPreflightCache.invalidate()
        let first = XcodeBuildServerPreflightCache.runPreflight()
        let second = XcodeBuildServerPreflightCache.runPreflight()
        XCTAssertEqual(first, second)
    }

    func testForceRefreshInvalidatesCache() {
        XcodeBuildServerPreflightCache.invalidate()
        _ = XcodeBuildServerPreflightCache.runPreflight()
        let refreshed = XcodeBuildServerPreflightCache.runPreflight(forceRefresh: true)
        XCTAssertNotNil(refreshed.xcodeVersion)
    }
}
#endif
