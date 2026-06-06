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

    public static var languagePreference: LanguagePreference {
        languagePreferenceProvider()
    }
}
