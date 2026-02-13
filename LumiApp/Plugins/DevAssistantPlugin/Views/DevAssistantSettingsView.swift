import SwiftUI

struct DevAssistantSettingsView: View {
    // Anthropic
    @AppStorage("DevAssistant_ApiKey_Anthropic") var apiKeyAnthropic: String = ""
    @AppStorage("DevAssistant_Model_Anthropic") var modelAnthropic: String = "claude-3-5-sonnet-20240620"

    // OpenAI
    @AppStorage("DevAssistant_ApiKey_OpenAI") var apiKeyOpenAI: String = ""
    @AppStorage("DevAssistant_Model_OpenAI") var modelOpenAI: String = "gpt-4o"

    // DeepSeek
    @AppStorage("DevAssistant_ApiKey_DeepSeek") var apiKeyDeepSeek: String = ""
    @AppStorage("DevAssistant_Model_DeepSeek") var modelDeepSeek: String = "deepseek-chat"

    // Zhipu AI
    @AppStorage("DevAssistant_ApiKey_Zhipu") var apiKeyZhipu: String = ""
    @AppStorage("DevAssistant_Model_Zhipu") var modelZhipu: String = "glm-4"

    var body: some View {
        Form {
            Section("Anthropic (Claude)") {
                SecureField("API Key", text: $apiKeyAnthropic)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(DesignTokens.Material.glass)
                    .cornerRadius(8)
                GlassTextField(title: LocalizedStringKey("Model"), text: $modelAnthropic, placeholder: LocalizedStringKey(modelAnthropic))
                Link("Get API Key", destination: URL(string: "https://console.anthropic.com/")!)
                    .font(.caption)
            }

            Section("OpenAI") {
                SecureField("API Key", text: $apiKeyOpenAI)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(DesignTokens.Material.glass)
                    .cornerRadius(8)
                GlassTextField(title: LocalizedStringKey("Model"), text: $modelOpenAI, placeholder: LocalizedStringKey(modelOpenAI))
            }

            Section("DeepSeek") {
                SecureField("API Key", text: $apiKeyDeepSeek)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(DesignTokens.Material.glass)
                    .cornerRadius(8)
                GlassTextField(title: LocalizedStringKey("Model"), text: $modelDeepSeek, placeholder: LocalizedStringKey(modelDeepSeek))
                Link("Get API Key", destination: URL(string: "https://platform.deepseek.com/")!)
                    .font(.caption)
            }

            Section("Zhipu AI") {
                SecureField("API Key", text: $apiKeyZhipu)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(DesignTokens.Material.glass)
                    .cornerRadius(8)
                GlassTextField(title: LocalizedStringKey("Model"), text: $modelZhipu, placeholder: LocalizedStringKey(modelZhipu))
                Link("Get API Key", destination: URL(string: "https://bigmodel.cn/")!)
                    .font(.caption)
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 400)
    }
}

// MARK: - Preview

#Preview("Settings") {
    DevAssistantSettingsView()
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(DevAssistantPlugin.navigationId)
        .hideTabPicker()
        .inRootView()
        .withDebugBar()
}
