import Foundation
import HttpKit
import LumiKernel
import LLMKit
import LumiKernel
import Testing
@testable import LLMProviderXiaomiPlugin

@Suite(.serialized)
struct PluginLLMProviderXiaomiTests {
    @Test func pluginMetadata() {
        #expect(XiaomiPlugin.info.id.isEmpty == false)
        #expect(XiaomiPlugin.info.displayName.isEmpty == false)
        #expect(XiaomiPlugin.info.description.isEmpty == false)
        #expect(XiaomiPlugin.iconName.isEmpty == false)
        #expect(XiaomiPlugin.category == .llmProvider)
    }

    @Test func providerMetadata() {
        #expect(XiaomiProvider.info.id == "xiaomi")
        #expect(XiaomiProvider.info.displayName.isEmpty == false)
        #expect(XiaomiProvider.info.defaultModel.isEmpty == false)
    }

    @Test func apiProviderMetadata() {
        #expect(XiaomiAPIProvider.info.id == "xiaomi-api")
        #expect(XiaomiAPIProvider.info.displayName.isEmpty == false)
        #expect(XiaomiAPIProvider.info.defaultModel.isEmpty == false)
    }

    @Test func providersUseDistinctAPIKeyStorage() {
        // TokenPlan 与小米 API 是独立服务，API Key 必须分开存储。
        // 通过 info.id 区分（重构后 apiKeyStorageKey 已是 internal 细节，
        // 由 info 内部按 id 派生 Keychain 键）。
        #expect(XiaomiProvider.info.id != XiaomiAPIProvider.info.id)
    }

    @Test func unsupportedTokenPlanModelMapsToStructuredFailure() {
        let body = #"{"error":{"code":"400","message":"Not supported model mimo-v2-flash","param":"Param Incorrect"}}"#
        let error = HTTPClientError.httpError(statusCode: 400, message: body)

        #expect(AvailabilityService.isUnsupportedModelError(error))

        let mapped = AvailabilityService.mapFriendlyFailureResult(
            .unavailable(LLMFailureDetailResolver.resolve(from: error)),
            kind: .tokenPlan
        )

        guard case .unavailable(let failure) = mapped else {
            Issue.record("Expected unavailable result")
            return
        }

        #expect(failure.reason == .unsupportedModel)
        #expect(failure.availabilityDisplayText.contains("Token Plan"))
        #expect(!failure.availabilityDisplayText.contains("mimo-v2-flash"))
    }

    @Test func invalidAPIKeyMapsToFriendlyMessage() {
        let body = #"{"error":{"message":"invalid_api_key","type":"invalid_request_error"}}"#
        let error = HTTPClientError.httpError(statusCode: 401, message: body)

        let mapped = AvailabilityService.mapFriendlyFailureResult(
            .unavailable(LLMFailureDetailResolver.resolve(from: error)),
            kind: .api
        )

        guard case .unavailable(let failure) = mapped else {
            Issue.record("Expected unavailable result")
            return
        }

        #expect(failure.reason == nil)
        #expect(failure.availabilityDisplayText.contains("API Key"))
        #expect(!failure.availabilityDisplayText.contains("invalid_api_key"))
    }

    @Test func quotaExhaustedMapsToFriendlyMessage() {
        let body = #"{"error":{"message":"quota exhausted"}}"#
        let error = HTTPClientError.httpError(statusCode: 429, message: body)

        let mapped = AvailabilityService.mapFriendlyFailureResult(
            .unavailable(LLMFailureDetailResolver.resolve(from: error)),
            kind: .tokenPlan
        )

        guard case .unavailable(let failure) = mapped else {
            Issue.record("Expected unavailable result")
            return
        }

        #expect(!failure.availabilityDisplayText.contains("{"))
        #expect(!failure.availabilityDisplayText.contains("quota exhausted"))
        #expect(failure.hasTransportDiagnostics)
        #expect(failure.httpStatusCode == 429)
        #expect(failure.transportDetails?.contains("quota exhausted") == true)
    }
}
