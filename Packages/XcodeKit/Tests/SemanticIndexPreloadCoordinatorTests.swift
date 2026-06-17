#if canImport(XCTest)
import XCTest
@testable import XcodeKit

@MainActor
final class SemanticIndexPreloadCoordinatorTests: XCTestCase {
    func testPauseBlocksPreloading() {
        SemanticIndexPreloadCoordinator.pause()
        XCTAssertFalse(
            SemanticIndexPreloadCoordinator.shouldContinuePreloading(
                activeProjectPath: "/tmp/Other",
                projectPath: "/tmp/App"
            )
        )
        SemanticIndexPreloadCoordinator.scheduleResume(after: 0)
    }

    func testExcludesActiveProjectPath() async {
        await MainActor.run {
            SemanticIndexPreloadCoordinator.scheduleResume(after: 0)
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        let path = "/tmp/Lumi"
        let shouldContinue = await MainActor.run {
            SemanticIndexPreloadCoordinator.shouldContinuePreloading(
                activeProjectPath: path,
                projectPath: path
            )
        }
        XCTAssertFalse(shouldContinue)
    }
}
#endif
