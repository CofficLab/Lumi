import XCTest
@testable import Lumi

final class AutomationServerTests: XCTestCase {
    func testCompleteHTTPRequestWaitsForDeclaredBodyLength() {
        let body = #"{"action":"automation.debug_state"}"#
        let fullRequest = [
            "POST /api/action HTTP/1.1",
            "Host: localhost",
            "Content-Type: application/json",
            "Content-Length: \(body.utf8.count)",
            "",
            body,
        ].joined(separator: "\r\n")

        let splitIndex = fullRequest.utf8.count - 4
        let partial = Data(fullRequest.utf8.prefix(splitIndex))
        let complete = Data(fullRequest.utf8)

        XCTAssertNil(AutomationServer.completeHTTPRequestData(from: partial))
        XCTAssertEqual(AutomationServer.completeHTTPRequestData(from: complete), complete)
    }

    func testCompleteHTTPRequestIgnoresExtraBytesAfterBody() {
        let body = #"{"action":"automation.debug_state"}"#
        let fullRequest = [
            "POST /api/action HTTP/1.1",
            "Host: localhost",
            "Content-Length: \(body.utf8.count)",
            "",
            body,
        ].joined(separator: "\r\n")
        let combined = Data((fullRequest + "EXTRA").utf8)

        let request = AutomationServer.completeHTTPRequestData(from: combined)

        XCTAssertEqual(request, Data(fullRequest.utf8))
    }

    func testCompleteHTTPRequestHandlesHeaderOnlyRequest() {
        let request = [
            "GET /api/action HTTP/1.1",
            "Host: localhost",
            "",
            "",
        ].joined(separator: "\r\n")
        let data = Data(request.utf8)

        XCTAssertEqual(AutomationServer.completeHTTPRequestData(from: data), data)
    }

    func testCompleteHTTPRequestDoesNotTruncateForNegativeContentLength() {
        let request = [
            "POST /api/action HTTP/1.1",
            "Host: localhost",
            "Content-Length: -1",
            "",
            #"{"action":"automation.debug_state"}"#,
        ].joined(separator: "\r\n")
        let headerOnly = request.components(separatedBy: "\r\n\r\n")[0] + "\r\n\r\n"

        XCTAssertEqual(
            AutomationServer.completeHTTPRequestData(from: Data(request.utf8)),
            Data(headerOnly.utf8)
        )
    }

    func testCompleteHTTPRequestWaitsWhenContentLengthWouldOverflow() {
        let request = [
            "POST /api/action HTTP/1.1",
            "Host: localhost",
            "Content-Length: \(Int.max)",
            "",
            "{}",
        ].joined(separator: "\r\n")

        XCTAssertNil(AutomationServer.completeHTTPRequestData(from: Data(request.utf8)))
    }

    func testFirstBindablePortSkipsUnavailableCandidates() {
        let result = AutomationServer.firstBindablePort(in: [18765, 18766, 18767]) { port in
            port == 18767
        }

        XCTAssertEqual(result?.port, 18767)
        XCTAssertEqual(result?.remainingPorts, [])
    }

    func testFirstBindablePortKeepsRemainingFallbacks() {
        let result = AutomationServer.firstBindablePort(in: [18765, 18766, 18767]) { port in
            port == 18766
        }

        XCTAssertEqual(result?.port, 18766)
        XCTAssertEqual(result?.remainingPorts, [18767])
    }

    func testFirstBindablePortReturnsNilWhenAllCandidatesUnavailable() {
        let result = AutomationServer.firstBindablePort(in: [18765, 18766]) { _ in false }

        XCTAssertNil(result)
    }
}
