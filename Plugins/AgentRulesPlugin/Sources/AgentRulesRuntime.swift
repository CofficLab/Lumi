import LumiKernel

@MainActor
public enum AgentRulesRuntime {
    public static var currentProjectPathProvider: () -> String = { "" }
    public static var languagePreferenceProvider: () -> LumiLanguagePreference = { .english }

    public static var currentProjectPath: String {
        currentProjectPathProvider()
    }

    public static var languagePreference: LumiLanguagePreference {
        languagePreferenceProvider()
    }
}
