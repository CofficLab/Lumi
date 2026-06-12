import AgentToolKit

@MainActor
public enum AgentRulesRuntime {
    public static var currentProjectPathProvider: () -> String = { "" }
    public static var languagePreferenceProvider: () -> LanguagePreference = { .current }

    public static var currentProjectPath: String {
        currentProjectPathProvider()
    }

    public static var languagePreference: LanguagePreference {
        languagePreferenceProvider()
    }
}
