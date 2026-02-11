import SwiftUI

struct DevAssistantSettingsView: View {
    // Anthropic
    @AppStorage("DevAssistant_ApiKey_Anthropic") var apiKeyAnthropic: String = ""
    @AppStorage("DevAssistant_Model_Anthropic") var modelAnthropic: String = "claude-3-5-sonnet-20240620"
    
    // OpenAI
    @AppStorage("DevAssistant_ApiKey_OpenAI") var apiKeyOpenAI: String = ""
    @AppStorage("DevAssistant_Model_OpenAI") var modelOpenAI: String = "gpt-4o"
    @AppStorage("DevAssistant_BaseURL_OpenAI") var baseURLOpenAI: String = "https://api.openai.com/v1/chat/completions"
    
    // DeepSeek
    @AppStorage("DevAssistant_ApiKey_DeepSeek") var apiKeyDeepSeek: String = ""
    @AppStorage("DevAssistant_Model_DeepSeek") var modelDeepSeek: String = "deepseek-chat"
    @AppStorage("DevAssistant_BaseURL_DeepSeek") var baseURLDeepSeek: String = "https://api.deepseek.com/chat/completions"
    
    var body: some View {
        Form {
            Section("Anthropic (Claude)") {
                SecureField("API Key", text: $apiKeyAnthropic)
                    .textFieldStyle(.roundedBorder)
                TextField("Model", text: $modelAnthropic)
                    .textFieldStyle(.roundedBorder)
                Link("Get API Key", destination: URL(string: "https://console.anthropic.com/")!)
                    .font(.caption)
            }
            
            Section("OpenAI") {
                SecureField("API Key", text: $apiKeyOpenAI)
                    .textFieldStyle(.roundedBorder)
                TextField("Model", text: $modelOpenAI)
                    .textFieldStyle(.roundedBorder)
                TextField("Base URL", text: $baseURLOpenAI)
                    .textFieldStyle(.roundedBorder)
            }
            
            Section("DeepSeek") {
                SecureField("API Key", text: $apiKeyDeepSeek)
                    .textFieldStyle(.roundedBorder)
                TextField("Model", text: $modelDeepSeek)
                    .textFieldStyle(.roundedBorder)
                TextField("Base URL", text: $baseURLDeepSeek)
                    .textFieldStyle(.roundedBorder)
                Link("Get API Key", destination: URL(string: "https://platform.deepseek.com/")!)
                    .font(.caption)
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 400)
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .withDebugBar()
}
