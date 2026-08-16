import XCTest
@testable import ProviderLLM

final class ProviderLLMTests: XCTestCase {
    func testDefaultProviderIsExplicitlyUnavailable() async {
        do {
            _ = try await DefaultLLMProviding().complete(
                LLMRequest(conversationID: UUID(), messages: [])
            )
            XCTFail("expected not configured")
        } catch let error as LLMProviderError {
            XCTAssertEqual(error, .notConfigured)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
