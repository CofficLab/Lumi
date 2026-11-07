import Foundation
import Testing
@testable import LumiUI

struct AppHTTPResponseTests {
    @Test
    func prettyPrintedJSONFormatsObject() {
        let input = #"{"b":2,"a":1}"#
        let output = AppHTTPResponse.prettyPrintedJSON(from: input)

        #expect(output != nil)
        #expect(output?.contains("\"a\" : 1") == true)
        #expect(output?.contains("\"b\" : 2") == true)
    }

    @Test
    func isValidJSONRejectsPlainText() {
        #expect(AppHTTPResponse.isValidJSON("not json") == false)
        #expect(AppHTTPResponse.isValidJSON(#"{"ok":true}"#) == true)
    }

    @Test
    func copyTextIncludesStatusAndBody() {
        let response = AppHTTPResponse(
            statusCode: 429,
            body: #"{"error":"too many requests"}"#
        )

        #expect(response.copyText.contains("HTTP Status: 429"))
        #expect(response.copyText.contains("Response Body:"))
        #expect(response.copyText.contains("too many requests"))
    }

    @Test
    func statusToneMapsFamilies() {
        #expect(AppHTTPStatusTone.tone(for: 200) == .success)
        #expect(AppHTTPStatusTone.tone(for: 302) == .redirect)
        #expect(AppHTTPStatusTone.tone(for: 404) == .clientError)
        #expect(AppHTTPStatusTone.tone(for: 500) == .serverError)
    }
}
