#if canImport(XCTest)
import XCTest
@testable import XcodeKit

final class SemanticIndexJobControllerTests: XCTestCase {
    @MainActor
    func testBeginJobIncrementsGeneration() {
        let controller = SemanticIndexJobController.shared
        controller.cancelCurrentJob()
        let first = controller.beginJob(priority: .activeWorkspace)
        let second = controller.beginJob(priority: .activeWorkspace)
        XCTAssertNotEqual(first.jobID, second.jobID)
        XCTAssertGreaterThan(second.generation, first.generation)
    }

    @MainActor
    func testRunReturnsCancelledWhenSuperseded() async {
        let controller = SemanticIndexJobController.shared
        controller.cancelCurrentJob()
        let first = controller.beginJob(priority: .activeWorkspace)
        let second = controller.beginJob(priority: .activeWorkspace)

        let result = await controller.run(
            generation: first.generation,
            priority: .activeWorkspace
        ) {
            try? await Task.sleep(nanoseconds: 500_000_000)
            return SemanticIndexJobResult()
        }
        XCTAssertTrue(result.wasCancelled)
        XCTAssertGreaterThan(second.generation, first.generation)
    }
}
#endif
