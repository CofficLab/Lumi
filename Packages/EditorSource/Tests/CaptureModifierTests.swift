import XCTest
@testable import EditorSource

final class CaptureModifierTests: XCTestCase {
    func testStringValueFromStringRoundTrip() {
        for modifier in CaptureModifier.allCases {
            XCTAssertEqual(
                CaptureModifier.fromString(modifier.stringValue),
                modifier,
                "expected \(modifier.stringValue) to parse back to \(modifier)"
            )
        }
    }

    func testFromStringRejectsUnknownStrings() {
        XCTAssertNil(CaptureModifier.fromString(""))
        XCTAssertNil(CaptureModifier.fromString("not-a-modifier"))
        XCTAssertNil(CaptureModifier.fromString("Declaration"))
    }

    func testModifierSetInsertAndValues() {
        var set = CaptureModifierSet()
        XCTAssertTrue(set.values.isEmpty)

        set.insert(.declaration)
        set.insert(.static)
        XCTAssertEqual(set.values, [.declaration, .static])
        XCTAssertEqual(set, [.declaration, .static])

        set.insert(.declaration) // Inserting twice is idempotent.
        XCTAssertEqual(set.values, [.declaration, .static])
    }

    func testModifierSetValuesIgnoresGarbageBits() {
        let garbage = CaptureModifierSet(rawValue: 1 << 64)
        XCTAssertTrue(garbage.values.isEmpty)
    }
}
