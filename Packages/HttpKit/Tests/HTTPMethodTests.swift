import Foundation
import Testing
@testable import HttpKit

@Suite("HTTPMethod")
struct HTTPMethodTests {
    @Test("GET rawValue is GET")
    func getRawValue() {
        #expect(HTTPMethod.get.rawValue == "GET")
    }

    @Test("POST rawValue is POST")
    func postRawValue() {
        #expect(HTTPMethod.post.rawValue == "POST")
    }

    @Test("PUT rawValue is PUT")
    func putRawValue() {
        #expect(HTTPMethod.put.rawValue == "PUT")
    }

    @Test("PATCH rawValue is PATCH")
    func patchRawValue() {
        #expect(HTTPMethod.patch.rawValue == "PATCH")
    }

    @Test("DELETE rawValue is DELETE")
    func deleteRawValue() {
        #expect(HTTPMethod.delete.rawValue == "DELETE")
    }
}
