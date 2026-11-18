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
        guard case .integer(let n) = obj["n"] else { return XCTFail("n 应为 integer") }
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
            "id": .integer(1),
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

    /// #355：超出 Double 安全整数范围的合法 JSON-RPC id 必须无损往返。
    func testLargeIntegerPreservesPrecision() throws {
        let json = "9007199254740993"
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        guard case .integer(let i) = value else {
            return XCTFail("2^53+1 应为 integer")
        }
        XCTAssertEqual(i, 9_007_199_254_740_993)

        let encoded = String(data: try JSONEncoder().encode(value), encoding: .utf8)
        XCTAssertEqual(encoded, "9007199254740993")
    }

    func testFractionalNumberStaysNumber() throws {
        let value = try JSONDecoder().decode(JSONValue.self, from: Data("3.5".utf8))
        XCTAssertEqual(value, .number(3.5))
    }
}
