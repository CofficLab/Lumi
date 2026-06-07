import AgentToolKit
import Foundation
import LLMKit
import LumiCoreKit

@MainActor
public enum MessageRendererRuntime {
    public static var languagePreferenceProvider: () -> LanguagePreference = { .current }
    public static var showsAssistantHeaderProvider: () -> Bool = { false }
    public static var enqueueText: (String) -> Void = { _ in }
    public static var cancelTurn: (UUID) -> Void = { _ in }
    public static var selectedProviderIdProvider: () -> String = { "" }
    public static var providerTypeProvider: (String) -> (any SuperLLMProvider.Type)? = { _ in nil }
    public static var providerInfoProvider: (String) -> LLMProviderInfo? = { _ in nil }
    public static var localModelInfoProvider: (String, String) async -> LocalModelInfo? = { _, _ in nil }
    public static var respondToToolPermission: @MainActor (UUID, UUID, String, Bool) async -> Void = { _, _, _, _ in }
    public static var evaluateToolPermissionRisk: @MainActor (String, String) -> CommandRiskLevel = { _, _ in .high }

    public static var languagePreference: LanguagePreference {
        languagePreferenceProvider()
    }
}
