import XCTest
@testable import LumiPreviewKit

@MainActor
final class InlinePreviewSessionTests: XCTestCase {

    func test_init_startsNotRunning() {
        let session = LumiPreviewFacade.InlinePreviewSession()

        XCTAssertFalse(session.isRunning)
    }

    func test_stop_whenNotRunning_isNoop() async {
        let session = LumiPreviewFacade.InlinePreviewSession()
        var terminatedCount = 0
        session.onTerminated = { terminatedCount += 1 }

        await session.stop()

        XCTAssertFalse(session.isRunning)
        XCTAssertEqual(terminatedCount, 0)
    }

    func test_commandMethods_whenNotRunning_throwExecutableNotFound() async {
        let session = LumiPreviewFacade.InlinePreviewSession()

        await assertExecutableNotFound {
            try await session.startFrameStream(width: 100, height: 50, scale: 2)
        }
        await assertExecutableNotFound {
            try await session.stopFrameStream()
        }
        await assertExecutableNotFound {
            try await session.resize(width: 100, height: 50, scale: 2)
        }
        await assertExecutableNotFound {
            try await session.setPolicy(.idle)
        }
        await assertExecutableNotFound {
            try await session.loadDylib(path: "/tmp/nope.dylib")
        }
        await assertExecutableNotFound {
            try await session.unloadDylib()
        }
        await assertExecutableNotFound {
            try await session.requestEntryDebugState()
        }
        await assertExecutableNotFound {
            try await session.forwardInputEvent(.flagsChanged(modifiers: [.command]))
        }
    }

    func test_sendInputEventBestEffort_whenNotRunning_isNoop() {
        let session = LumiPreviewFacade.InlinePreviewSession()

        session.sendInputEventBestEffort(.flagsChanged(modifiers: [.command]))

        XCTAssertFalse(session.isRunning)
    }

    func test_startAndFrameStream_deliversCallbacks() async throws {
        guard LumiPreviewFacade.HostExecutableResolver.resolve() != nil else {
            throw XCTSkip("LumiPreviewHostApp binary not found; run `swift build` first.")
        }

        let session = LumiPreviewFacade.InlinePreviewSession()
        let frameExpectation = expectation(description: "session received frame")
        let policyExpectation = expectation(description: "session received interactive policy")
        var pendingFrameExpectation: XCTestExpectation? = frameExpectation
        var pendingPolicyExpectation: XCTestExpectation? = policyExpectation
        var receivedFrame: LumiPreviewFacade.IOSurfaceFrame?
        var receivedPolicy: LumiPreviewFacade.FrameStreamPolicy?

        session.onFrame = { frame in
            receivedFrame = frame
            if let expectation = pendingFrameExpectation {
                pendingFrameExpectation = nil
                expectation.fulfill()
            }
        }
        session.onPolicy = { policy in
            receivedPolicy = policy
            if policy == .interactive, let expectation = pendingPolicyExpectation {
                pendingPolicyExpectation = nil
                expectation.fulfill()
            }
        }

        try await session.start()
        XCTAssertTrue(session.isRunning)

        try await session.start()
        XCTAssertTrue(session.isRunning)

        let response = try await session.startFrameStream(width: 64, height: 48, scale: 1)
        XCTAssertTrue(response.success)

        await fulfillment(of: [frameExpectation, policyExpectation], timeout: 5)

        XCTAssertEqual(receivedFrame?.width, 64)
        XCTAssertEqual(receivedFrame?.height, 48)
        XCTAssertEqual(receivedFrame?.scale, 1)
        XCTAssertEqual(receivedPolicy, .interactive)

        let stopStreamResponse = try await session.stopFrameStream()
        XCTAssertTrue(stopStreamResponse.success)

        await session.stop()
        XCTAssertFalse(session.isRunning)
    }

    func test_sessionErrorDescriptions() {
        XCTAssertEqual(
            LumiPreviewFacade.InlinePreviewSession.SessionError.executableNotFound.errorDescription,
            "LumiPreviewHostApp executable not found. Set the LUMI_INLINE_PREVIEW_HOST_PATH environment variable or embed it in the app bundle."
        )

        let underlying = NSError(domain: "InlinePreviewSessionTests", code: 7, userInfo: [
            NSLocalizedDescriptionKey: "fixture failure"
        ])
        XCTAssertEqual(
            LumiPreviewFacade.InlinePreviewSession.SessionError.underlying(underlying).errorDescription,
            "fixture failure"
        )
    }

    private func assertExecutableNotFound(
        _ operation: () async throws -> LumiPreviewFacade.HostResponse,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await operation()
            XCTFail("Expected executableNotFound", file: file, line: line)
        } catch LumiPreviewFacade.InlinePreviewSession.SessionError.executableNotFound {
            // Expected.
        } catch {
            XCTFail("Expected executableNotFound, got \(error)", file: file, line: line)
        }
    }
}
