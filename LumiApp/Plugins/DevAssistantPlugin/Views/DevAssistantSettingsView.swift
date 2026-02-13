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
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 8) {
                Text("Providers")
                    .font(DesignTokens.Typography.caption1)
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)

                ForEach(LLMProvider.allCases) { provider in
                    Button(action: {
                        selectedProvider = provider
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: iconName(for: provider))
                                .font(.system(size: 14))
                                .frame(width: 20, height: 20)
                            
                            Text(provider.rawValue)
                                .font(DesignTokens.Typography.body)
                            
                            Spacer()
                            
                            if provider == selectedProvider {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(provider == selectedProvider ? Color.accentColor.opacity(0.1) : Color.clear)
                    )
                    .foregroundColor(provider == selectedProvider ? Color.accentColor : DesignTokens.Color.semantic.textPrimary)
                }
                
                Spacer()
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 10)
            .frame(width: 200)
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
                            
                            // Model Display (Hardcoded)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Model")
                                    .font(DesignTokens.Typography.caption1)
                                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                                
                                HStack {
                                    Text(selectedProvider.defaultModel)
                                        .font(DesignTokens.Typography.body)
                                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "lock.fill")
                                        .font(.caption)
                                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
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
                .padding(32)
            }
        }
        .frame(width: 700, height: 450)
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
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(DevAssistantPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
