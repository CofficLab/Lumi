#if canImport(XCTest)
import XCTest
@testable import XcodeKit

final class SemanticIndexResourceManagerTests: XCTestCase {
    func testEnforceDiskQuotaAsyncDoesNotBlockMainActor() async {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("SemanticIndexResourceManagerTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let expectation = expectation(description: "main actor responsive")
        await MainActor.run {
            Task { @MainActor in
                expectation.fulfill()
            }
        }
        async let quota = SemanticIndexResourceManager.enforceDiskQuotaAsync(in: temp)
        _ = await quota
        await fulfillment(of: [expectation], timeout: 1)
    }
}
#endif
