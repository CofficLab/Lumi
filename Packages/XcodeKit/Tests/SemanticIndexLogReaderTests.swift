#if canImport(XCTest)
import XCTest
@testable import XcodeKit

final class SemanticIndexLogReaderTests: XCTestCase {
    func testTailExcerptReadsOnlyEndOfLargeFile() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("SemanticIndexLogReaderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let logURL = temp.appendingPathComponent("semantic-index-build.log")
        let filler = String(repeating: "x", count: 200_000)
        let tailMarker = "TAIL_MARKER_LINE"
        try (filler + "\n" + tailMarker + "\n").write(to: logURL, atomically: true, encoding: .utf8)

        let excerpt = SemanticIndexLogReader.tailExcerpt(at: logURL, maxTailBytes: 4_096)
        XCTAssertEqual(excerpt, tailMarker)
    }
}
#endif
