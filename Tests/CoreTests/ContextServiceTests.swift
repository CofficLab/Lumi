#if canImport(XCTest)
import XCTest
@testable import Lumi

final class ContextServiceTests: XCTestCase {
    @MainActor
    func testSwitchProjectUpdatesContextProjectRoot() async throws {
        let contextService = ContextService()
        let projectVM = WindowProjectVM(
            contextService: contextService,
            llmService: LLMService(registry: LLMProviderRegistry())
        )
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiContextProject-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        projectVM.switchProject(
            to: Project(name: "Context Project", path: root.path),
            reason: "test"
        )

        let prompt = await waitForContextPrompt(
            contextService,
            containing: "- Project Root: \(root.standardizedFileURL.path)"
        )
        XCTAssertTrue(prompt.contains("- Project Root: \(root.standardizedFileURL.path)"))
    }

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

    private func waitForContextPrompt(
        _ contextService: ContextService,
        containing expected: String
    ) async -> String {
        var latest = ""
        for _ in 0..<50 {
            latest = await contextService.getContextPrompt()
            if latest.contains(expected) {
                return latest
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return latest
    }
}
#endif
