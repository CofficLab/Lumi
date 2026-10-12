#if canImport(XCTest)
import Foundation
import LanguageServerProtocol
import XCTest
@testable import EditorService

@MainActor
final class LSPCoordinatorJumpToDefinitionTests: XCTestCase {
    func testRequestDefinitionReturnsNilBeforeDocumentOpen() async {
        let coordinator = LSPCoordinator()

        let result = await coordinator.requestDefinition(line: 0, character: 0)

        XCTAssertNil(result)
    }

    func testRequestDefinitionForwardsURIToServiceLayer() async {
        let fileURL = URL(fileURLWithPath: "/tmp/LSPCoordinatorJumpTests.swift")
        let expected = Location(
            uri: fileURL.absoluteString,
            range: LSPRange(
                start: Position(line: 0, character: 6),
                end: Position(line: 0, character: 11)
            )
        )
        let capturedURI = URICaptureBox()
        let coordinator = LSPCoordinator(
            requestDefinitionOperation: { uri, line, character in
                capturedURI.value = uri
                XCTAssertEqual(line, 2)
                XCTAssertEqual(character, 4)
                return expected
            }
        )

        await coordinator.openFile(
            uri: fileURL.absoluteString,
            languageId: "swift",
            content: "func greet() {\n    greet()\n}\n",
            version: 1
        )
        let result = await coordinator.requestDefinition(line: 2, character: 4)

        XCTAssertEqual(capturedURI.value, fileURL.absoluteString)
        XCTAssertEqual(result?.uri, expected.uri)
    }

    func testRequestDefinitionWaitsForInFlightOpenTask() async {
        let fileURL = URL(fileURLWithPath: "/tmp/LSPCoordinatorJumpTests-Wait.swift")
        let gate = AsyncTestGate()
        let order = OrderCaptureBox()

        let coordinator = LSPCoordinator(
            requestDefinitionOperation: { uri, _, _ in
                order.append("definition")
                return Location(
                    uri: uri,
                    range: LSPRange(
                        start: Position(line: 0, character: 0),
                        end: Position(line: 0, character: 0)
                    )
                )
            },
            openDocumentOperation: { _, _, _, _ in
                order.append("open-started")
                await gate.notifyEntered()
                await gate.waitUntilReleased()
                order.append("open-finished")
            }
        )

        let openTask = Task {
            await coordinator.openFile(
                uri: fileURL.absoluteString,
                languageId: "swift",
                content: "let value = 1\n",
                version: 1
            )
        }

        await gate.waitUntilEntered()
        let definitionTask = Task {
            _ = await coordinator.requestDefinition(line: 0, character: 4)
        }

        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(order.values, ["open-started"])

        await gate.release()
        await openTask.value
        await definitionTask.value

        XCTAssertEqual(order.values, ["open-started", "open-finished", "definition"])
    }
}

private final class URICaptureBox: @unchecked Sendable {
    var value: String?
}

private final class OrderCaptureBox: @unchecked Sendable {
    private(set) var values: [String] = []

    func append(_ value: String) {
        values.append(value)
    }
}

private actor AsyncTestGate {
    private var didEnter = false
    private var enteredWaiter: CheckedContinuation<Void, Never>?
    private var releaseWaiter: CheckedContinuation<Void, Never>?

    func notifyEntered() {
        didEnter = true
        enteredWaiter?.resume()
        enteredWaiter = nil
    }

    func waitUntilEntered() async {
        if didEnter { return }
        await withCheckedContinuation { enteredWaiter = $0 }
    }

    func waitUntilReleased() async {
        await withCheckedContinuation { releaseWaiter = $0 }
    }

    func release() {
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
}
#endif
