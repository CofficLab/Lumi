#if canImport(XCTest)
import XCTest
@testable import Lumi

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
}

#endif
