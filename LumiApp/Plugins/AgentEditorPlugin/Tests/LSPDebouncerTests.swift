#if canImport(XCTest)
import XCTest
@testable import Lumi

private actor DebouncerHitBox {
    private var hitCount = 0

    func increment() {
        hitCount += 1
    }

    func value() -> Int {
        hitCount
    }
}

final class LSPDebouncerTests: XCTestCase {

    func testCancelAllPreventsPendingDebounceExecution() async {
        let debouncer = LSPDebouncer()
        let hits = DebouncerHitBox()

        async let result: Int? = debouncer.debounce(
            key: "completion",
            delay: 80_000_000
        ) {
            await hits.increment()
            return 42
        }

        try? await Task.sleep(for: .milliseconds(10))
        await debouncer.cancelAll()

        let resolved = await result
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertNil(resolved)
        XCTAssertEqual(await hits.value(), 0)
    }

    func testCancelAllResetsThrottleWindow() async {
        let debouncer = LSPDebouncer()
        let hits = DebouncerHitBox()

        let first = await debouncer.throttle(
            key: "hover",
            interval: 1_000_000_000
        ) {
            await hits.increment()
            return "first"
        }

        XCTAssertEqual(first, "first")
        XCTAssertEqual(await hits.value(), 1)

        let throttled = await debouncer.throttle(
            key: "hover",
            interval: 1_000_000_000
        ) {
            await hits.increment()
            return "second"
        }

        XCTAssertNil(throttled)
        XCTAssertEqual(await hits.value(), 1)

        await debouncer.cancelAll()

        let afterReset = await debouncer.throttle(
            key: "hover",
            interval: 1_000_000_000
        ) {
            await hits.increment()
            return "third"
        }

        XCTAssertEqual(afterReset, "third")
        XCTAssertEqual(await hits.value(), 2)
    }
}

#endif
