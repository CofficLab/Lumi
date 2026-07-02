import Foundation
import LumiCoreKit

public enum AvailabilityCheckStrategy: Sendable {
    case apiKeyOnly
    case chatPing(maxTokens: Int? = nil)
    case custom(@Sendable (String, String) async -> (isAvailable: Bool, failure: LumiLLMFailureDetail?))
}
