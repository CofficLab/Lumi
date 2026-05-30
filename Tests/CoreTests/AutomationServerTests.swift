#if canImport(XCTest)
import XCTest
@testable import Lumi

final class AutomationServerTests: XCTestCase {
    func testCandidatePortsStartAtPreferredPort() {
        XCTAssertEqual(
            AutomationServer.candidatePorts(preferredPort: 18_765, maxAttempts: 4),
            [18_765, 18_766, 18_767, 18_768]
        )
    }

    func testCandidatePortsDoNotOverflow() {
        XCTAssertEqual(
            AutomationServer.candidatePorts(preferredPort: UInt16.max - 1, maxAttempts: 4),
            [UInt16.max - 1, UInt16.max]
        )
    }

    func testCandidatePortsAreEmptyWhenNoAttemptsAreAllowed() {
        XCTAssertTrue(AutomationServer.candidatePorts(preferredPort: 18_765, maxAttempts: 0).isEmpty)
    }
}
#endif
