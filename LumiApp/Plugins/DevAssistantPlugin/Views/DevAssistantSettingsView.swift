import SwiftUI

struct DevAssistantSettingsView: View {
    // Anthropic
    @AppStorage("DevAssistant_ApiKey_Anthropic") var apiKeyAnthropic: String = ""

    // OpenAI
    @AppStorage("DevAssistant_ApiKey_OpenAI") var apiKeyOpenAI: String = ""

    // DeepSeek
    @AppStorage("DevAssistant_ApiKey_DeepSeek") var apiKeyDeepSeek: String = ""

    // Zhipu AI
    @AppStorage("DevAssistant_ApiKey_Zhipu") var apiKeyZhipu: String = ""

    @State private var selectedProvider: LLMProvider = .anthropic

    var body: some View {
        VStack(spacing: 0) {
            // Provider Selector (Horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(LLMProvider.allCases) { provider in
                        Button(action: {
                            selectedProvider = provider
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: iconName(for: provider))
                                    .font(.system(size: 14))
                                
                                Text(provider.rawValue)
                                    .font(DesignTokens.Typography.caption1)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(provider == selectedProvider ? Color.accentColor.opacity(0.1) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(provider == selectedProvider ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(provider == selectedProvider ? Color.accentColor : DesignTokens.Color.semantic.textSecondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(DesignTokens.Material.glassThick)
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.1))
                                .frame(width: 48, height: 48)
                            Image(systemName: iconName(for: selectedProvider))
                                .font(.title2)
                                .foregroundColor(.accentColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedProvider.rawValue)
                                .font(DesignTokens.Typography.bodyEmphasized)
                            Text("Configure API settings for \(selectedProvider.rawValue)")
                                .font(DesignTokens.Typography.caption1)
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        }
                    }
                    .padding(.bottom, 8)
                    
                    // Settings Card
                    GlassCard {
                        VStack(spacing: 20) {
                            GlassTextField(
                                title: LocalizedStringKey("API Key"),
                                text: bindingForApiKey,
                                placeholder: "sk-...",
                                isSecure: true
                            )
                            
                            // Supported Models
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Supported Models")
                                    .font(DesignTokens.Typography.caption1)
                                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                                
                                VStack(spacing: 8) {
                                    ForEach(selectedProvider.availableModels, id: \.self) { model in
                                        HStack {
                                            Text(model)
                                                .font(DesignTokens.Typography.body)
                                                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                                            
                                            Spacer()
                                            
                                            if model == selectedProvider.defaultModel {
                                                Text("Default")
                                                    .font(.caption2)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.accentColor.opacity(0.1))
                                                    .foregroundColor(.accentColor)
                                                    .cornerRadius(4)
                                            }
                                        }
                                        .padding(DesignTokens.Spacing.sm)
                                        .background(DesignTokens.Material.glass)
                                        .cornerRadius(DesignTokens.Radius.sm)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                        )
                                    }
                                }
                            }
                        }
                    }
                    
                    // Help Section
                    if let url = apiKeyUrl(for: selectedProvider) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                            Text("Need an API Key?")
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                            Link("Get it here", destination: url)
                                .font(DesignTokens.Typography.caption1)
                        }
                        .font(DesignTokens.Typography.caption1)
                        .padding(.horizontal, 8)
                    }
                    
                    Spacer()
                }
                .padding(20)
            }
        }
    }
    
    // MARK: - Helpers
    
    private var bindingForApiKey: Binding<String> {
        switch selectedProvider {
        case .anthropic: return $apiKeyAnthropic
        case .openai: return $apiKeyOpenAI
        case .deepseek: return $apiKeyDeepSeek
        case .zhipu: return $apiKeyZhipu
        }
    }

    private func iconName(for provider: LLMProvider) -> String {
        switch provider {
        case .anthropic: return "brain.head.profile"
        case .openai: return "bolt.fill"
        case .deepseek: return "magnifyingglass"
        case .zhipu: return "sparkles"
        }
    }
    
    private func apiKeyUrl(for provider: LLMProvider) -> URL? {
        switch provider {
        case .anthropic: return URL(string: "https://console.anthropic.com/")
        case .openai: return URL(string: "https://platform.openai.com/")
        case .deepseek: return URL(string: "https://platform.deepseek.com/")
        case .zhipu: return URL(string: "https://bigmodel.cn/")
        }
    }
}

#Preview("Settings") {
    DevAssistantSettingsView()
        .frame(width: 400, height: 500)
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(DevAssistantPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
