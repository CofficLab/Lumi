import Foundation
import HttpKit
import LumiCoreKit
import LLMKit
import LumiCoreKit
import Testing
@testable import LLMProviderZhipuPlugin

@Suite(.serialized)
struct PluginLLMProviderZhipuTests {
    @Test func pluginMetadata() {
        #expect(ZhipuPlugin.info.id.isEmpty == false)
        #expect(ZhipuPlugin.info.displayName.isEmpty == false)
        #expect(ZhipuPlugin.info.description.isEmpty == false)
        #expect(ZhipuPlugin.iconName.isEmpty == false)
        #expect(ZhipuPlugin.category == .llmProvider)
        #expect(ZhipuPlugin.policy == .alwaysOn)
    }

    @Test func providerMetadata() {
        #expect(ZhipuProvider.info.id == "zhipu")
        #expect(ZhipuProvider.info.displayName.isEmpty == false)
        #expect(ZhipuProvider.info.defaultModel.isEmpty == false)
        #expect(ZhipuProvider.apiKeyHelpURL != nil)
    }

    @MainActor
    @Test func renderersMatchRenderKind() {
        let conversationID = UUID()
        let apiKeyMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: ZhipuProvider.info.id,
            isError: true,
            renderKind: ZhipuRenderKind.apiKeyMissing
        )
        let forbiddenMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: ZhipuProvider.info.id,
            isError: true,
            rawErrorDetail: "HTTP 403",
            renderKind: ZhipuRenderKind.http(403)
        )
        let otherProviderMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: "openai",
            isError: true,
            renderKind: ZhipuRenderKind.http(403)
        )

        #expect(ApiKeyMissingRenderer.item.canRender(apiKeyMessage))
        #expect(!ApiKeyMissingRenderer.item.canRender(forbiddenMessage))
        #expect(Http403Renderer.item.canRender(forbiddenMessage))
        #expect(!Http403Renderer.item.canRender(otherProviderMessage))
        #expect(Http403Renderer.item.order > 160)
    }

    @MainActor
    @Test func httpErrorRendererMatchesOtherStatusCodes() {
        let conversationID = UUID()
        let rateLimited = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: ZhipuProvider.info.id,
            isError: true,
            renderKind: ZhipuRenderKind.http(429)
        )
        let forbidden = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: ZhipuProvider.info.id,
            isError: true,
            renderKind: ZhipuRenderKind.http(403)
        )

        #expect(HttpErrorRenderer.item.canRender(rateLimited))
        #expect(!HttpErrorRenderer.item.canRender(forbidden))
    }

    @MainActor
    @Test func requestFailedRendererMatchesRenderKind() {
        let message = LumiChatMessage(
            conversationID: UUID(),
            role: .error,
            content: "",
            providerID: ZhipuProvider.info.id,
            isError: true,
            renderKind: ZhipuRenderKind.requestFailed
        )

        #expect(RequestFailedRenderer.item.canRender(message))
    }

    @Test func rateLimitedShowsAPIErrorMessage() {
        let body = #"{"error":{"message":"rate limit exceeded"}}"#
        let error = HTTPClientError.httpError(statusCode: 429, message: body)

        #expect(AvailabilityService.isRateLimitedError(error))

        let mapped = AvailabilityService.mapFriendlyFailureResult(
            .unavailable(LLMFailureDetailResolver.resolve(from: error))
        )

        guard case .unavailable(let failure) = mapped else {
            Issue.record("Expected unavailable result")
            return
        }

        #expect(failure.availabilityDisplayText == "rate limit exceeded")
        #expect(!failure.availabilityDisplayText.contains("{"))
        #expect(failure.hasTransportDiagnostics)
        #expect(failure.httpStatusCode == 429)
        #expect(failure.transportDetails?.contains("rate limit exceeded") == true)
    }

    @Test func rateLimitedShowsZhipuNestedErrorMessage() {
        let body = #"{"error":{"code":"1302","message":"[1302][您的账户已达到速率限制，请您控制请求频率][202606261713470daee3d970fa4cbc]","type":"rate_limit_error"},"request_id":"202606261713470daee3d970fa4cbc","type":"error"}"#
        let error = HTTPClientError.httpError(statusCode: 429, message: body)

        let mapped = AvailabilityService.mapFriendlyFailureResult(
            .unavailable(LLMFailureDetailResolver.resolve(from: error))
        )

        guard case .unavailable(let failure) = mapped else {
            Issue.record("Expected unavailable result")
            return
        }

        #expect(failure.availabilityDisplayText.contains("速率限制"))
        #expect(failure.availabilityDisplayText.contains("1302"))
        #expect(!failure.availabilityDisplayText.contains("智谱额度"))
    }

    @Test func schedulerEnforcesMinimumInterval() async {
        let scheduler = AvailabilityScheduler(minimumInterval: .milliseconds(250))
        let start = ContinuousClock.now

        await scheduler.run { }
        await scheduler.run { }

        let elapsed = ContinuousClock.now - start
        #expect(elapsed >= .milliseconds(250))
    }

    @Test func schedulerSerializesConcurrentChecks() async {
        let scheduler = AvailabilityScheduler(minimumInterval: .milliseconds(200))
        let start = ContinuousClock.now

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await scheduler.run {
                    try? await Task.sleep(for: .milliseconds(30))
                }
            }
            group.addTask {
                await scheduler.run { }
            }
        }

        let elapsed = ContinuousClock.now - start
        #expect(elapsed >= .milliseconds(200))
    }
}
