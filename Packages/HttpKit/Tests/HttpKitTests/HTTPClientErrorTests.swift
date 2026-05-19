import Foundation
import Testing
@testable import HttpKit

@Suite("HTTPClientError")
struct HTTPClientErrorTests {
    @Test("jsonSerializationFailed returns correct description")
    func jsonSerializationFailed() {
        let underlying = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "bad json"])
        let error = HTTPClientError.jsonSerializationFailed(underlying: underlying)
        #expect(error.errorDescription?.contains("JSON") == true)
        #expect(error.errorDescription?.contains("bad json") == true)
    }

    @Test("requestFailed returns correct description")
    func requestFailed() {
        let underlying = NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "timeout"])
        let error = HTTPClientError.requestFailed(underlying: underlying)
        #expect(error.errorDescription?.contains("timeout") == true)
    }

    @Test("decodingFailed returns correct description")
    func decodingFailed() {
        let underlying = NSError(domain: "test", code: 3, userInfo: [NSLocalizedDescriptionKey: "decode err"])
        let error = HTTPClientError.decodingFailed(underlying: underlying)
        #expect(error.errorDescription?.contains("decode err") == true)
    }

    @Test("invalidResponse returns correct description")
    func invalidResponse() {
        let error = HTTPClientError.invalidResponse
        #expect(error.errorDescription != nil)
    }

    @Test("httpError returns correct description with status code and message")
    func httpError() {
        let error = HTTPClientError.httpError(statusCode: 404, message: "Not Found")
        #expect(error.errorDescription?.contains("404") == true)
        #expect(error.errorDescription?.contains("Not Found") == true)
    }
}
