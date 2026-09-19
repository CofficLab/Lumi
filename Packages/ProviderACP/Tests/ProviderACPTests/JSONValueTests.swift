import XCTest
@testable import ProviderACP

final class JSONValueTests: XCTestCase {
    func testDecodeAllKinds() throws {
        let json = """
        {"s":"text","n":42,"b":true,"nil":null,"arr":[1,2],"obj":{"k":"v"}}
        """
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        guard case .object(let obj) = value else {
            return XCTFail("应为 object")
        }
        guard case .string(let s) = obj["s"] else { return XCTFail("s 应为 string") }
        XCTAssertEqual(s, "text")
        guard case .number(let n) = obj["n"] else { return XCTFail("n 应为 number") }
        XCTAssertEqual(n, 42)
        guard case .bool(let b) = obj["b"] else { return XCTFail("b 应为 bool") }
        XCTAssertTrue(b)
        guard case .null = obj["nil"]! else { return XCTFail("nil 应为 null") }
        guard case .array(let arr) = obj["arr"] else { return XCTFail("arr 应为 array") }
        XCTAssertEqual(arr.count, 2)
        guard case .object(let nested) = obj["obj"] else { return XCTFail("obj 应为 object") }
        XCTAssertEqual(nested["k"], .string("v"))
    }

    func testRoundTrip() throws {
        let original: JSONValue = .object([
            "id": .number(1),
            "ok": .bool(true),
            "msg": .string("hi"),
        ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testStringifyAndDecoded() throws {
        struct Payload: Codable, Equatable {
            var sessionId: String
            var prompt: [ContentBlock]
        }
        let payload = Payload(
            sessionId: "sess_abc",
            prompt: [.text("hello")]
        )
        let value = try JSONValue.stringify(payload)
        let back: Payload = try value.decoded()
        XCTAssertEqual(payload, back)
    }
}
