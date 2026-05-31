#if canImport(XCTest)
import XCTest
@testable import Lumi

final class ContextServiceTests: XCTestCase {
    func testProcessCaptureHandlesLargeStdoutAndStderr() throws {
        let result = try ContextService.runProcessCapturingOutput(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: [
                "-c",
                """
                i=1
                while [ "$i" -le 300 ]; do
                  printf 'stdout-%03d-%0512d\\n' "$i" 0
                  printf 'stderr-%03d-%0512d\\n' "$i" 0 >&2
                  i=$((i + 1))
                done
                """
            ],
            currentDirectoryURL: nil
        )

        XCTAssertEqual(result.terminationStatus, 0)
        XCTAssertTrue(result.stdout.contains("stdout-300-"))
        XCTAssertTrue(result.stderr.contains("stderr-300-"))
        XCTAssertGreaterThan(result.stdout.count, 150_000)
        XCTAssertGreaterThan(result.stderr.count, 150_000)
    }
}
#endif
