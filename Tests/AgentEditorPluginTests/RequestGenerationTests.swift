#if canImport(XCTest)
import XCTest
@testable import Lumi

private actor AppliedValuesBox {
    private var values: [String] = []

    func append(_ value: String) {
        values.append(value)
    }

    func snapshot() -> [String] {
        values
    }
}

final class RequestGenerationTests: XCTestCase {

    func testStartsAtZero() {
        let gen = RequestGeneration()
        XCTAssertEqual(gen.generation, 0)
    }

    func testNextIncrements() {
        let gen = RequestGeneration()
        let first = gen.next()
        let second = gen.next()
        let third = gen.next()

        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 2)
        XCTAssertEqual(third, 3)
        XCTAssertEqual(gen.generation, 3)
    }

    func testIsCurrent() {
        let gen = RequestGeneration()
        let g1 = gen.next()
        let g2 = gen.next()

        XCTAssertFalse(gen.isCurrent(g1))
        XCTAssertTrue(gen.isCurrent(g2))
        XCTAssertFalse(gen.isCurrent(g1))
    }

    func testReset() {
        let gen = RequestGeneration()
        _ = gen.next()
        _ = gen.next()
        gen.reset()

        XCTAssertEqual(gen.generation, 0)
        let after = gen.next()
        XCTAssertEqual(after, 1)
    }

    func testInvalidateAdvancesGeneration() {
        let gen = RequestGeneration()
        let first = gen.next()
        let invalidated = gen.invalidate()
        let next = gen.next()

        XCTAssertEqual(first, 1)
        XCTAssertEqual(invalidated, 2)
        XCTAssertEqual(next, 3)
    }

    func testLifecycleAppliesOnlyLatestResult() async {
        let lifecycle = LSPRequestLifecycle()
        let applied = AppliedValuesBox()

        lifecycle.run(
            operation: {
                try? await Task.sleep(for: .milliseconds(80))
                return "old"
            },
            apply: { value in
                Task {
                    await applied.append(value)
                }
            }
        )

        lifecycle.run(
            operation: {
                try? await Task.sleep(for: .milliseconds(10))
                return "new"
            },
            apply: { value in
                Task {
                    await applied.append(value)
                }
            }
        )

        try? await Task.sleep(for: .milliseconds(180))
        let snapshot = await applied.snapshot()
        XCTAssertEqual(snapshot, ["new"])
    }

    func testLifecycleResetDropsPendingResult() async {
        let lifecycle = LSPRequestLifecycle()
        let applied = AppliedValuesBox()

        lifecycle.run(
            operation: {
                try? await Task.sleep(for: .milliseconds(60))
                return "stale"
            },
            apply: { value in
                Task {
                    await applied.append(value)
                }
            }
        )

        lifecycle.reset()

        try? await Task.sleep(for: .milliseconds(120))
        let snapshot = await applied.snapshot()
        XCTAssertTrue(snapshot.isEmpty)
    }

    func testLifecycleInvalidateDropsPendingResult() async {
        let lifecycle = LSPRequestLifecycle()
        let applied = AppliedValuesBox()

        lifecycle.run(
            operation: {
                try? await Task.sleep(for: .milliseconds(60))
                return "stale"
            },
            apply: { value in
                Task {
                    await applied.append(value)
                }
            }
        )

        lifecycle.invalidate()

        try? await Task.sleep(for: .milliseconds(120))
        let snapshot = await applied.snapshot()
        XCTAssertTrue(snapshot.isEmpty)
    }
}

#endif
