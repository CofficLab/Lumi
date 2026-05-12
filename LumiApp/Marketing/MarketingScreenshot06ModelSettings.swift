import SwiftUI

struct MarketingScreenshot06ModelSettings: View {
    var body: some View {
        MarketingScreenshotStage(
            eyebrow: "Model Settings",
            title: "Bring your preferred AI providers",
            subtitle: "Configure remote models, local providers and plugin behavior from Lumi's dedicated settings window."
        ) {
            MarketingMacWindow(title: "Settings") {
                MarketingSettingsMock()
            }
            .frame(height: 655)
        }
    }
}

private struct MarketingSettingsMock: View {
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color(red: 0.49, green: 0.44, blue: 1.00))
                    Text("Lumi")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)

                Divider().overlay(Color.white.opacity(0.10))

                VStack(spacing: 4) {
                    MarketingSettingsSidebarRow(title: "About", icon: "info.circle")
                    MarketingSettingsSidebarRow(title: "General", icon: "gearshape")
                    MarketingSettingsSidebarRow(title: "Editor", icon: "chevron.left.forwardslash.chevron.right")
                    MarketingSettingsSidebarRow(title: "Keyboard Shortcuts", icon: "keyboard")
                    MarketingSettingsSidebarRow(title: "Local Models", icon: "cpu")
                    MarketingSettingsSidebarRow(title: "Remote Providers", icon: "cloud.fill", selected: true)
                    MarketingSettingsSidebarRow(title: "Plugins", icon: "puzzlepiece.extension")
                    MarketingSettingsSidebarRow(title: "Theme", icon: "paintpalette")
                }
                .padding(12)

                Spacer()
            }
            .frame(width: 240)
            .background(Color(red: 0.128, green: 0.135, blue: 0.160))

            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Remote Providers")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Choose a cloud provider and set your default model.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                HStack(alignment: .top, spacing: 18) {
                    MarketingCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Cloud LLM Providers", systemImage: "cloud.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)

                            MarketingProviderRow(name: "OpenAI", detail: "GPT-5.5, GPT-5.4", selected: true)
                            MarketingProviderRow(name: "Anthropic", detail: "Claude Opus, Sonnet")
                            MarketingProviderRow(name: "Google", detail: "Gemini Pro")
                            MarketingProviderRow(name: "xAI", detail: "Grok")
                            MarketingProviderRow(name: "DeepSeek", detail: "Reasoning models")
                        }
                    }
                    .frame(width: 300)

                    VStack(spacing: 18) {
                        MarketingCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Label("API Key", systemImage: "key.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)

                                HStack(spacing: 10) {
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(Color(red: 1.00, green: 0.62, blue: 0.04))
                                    Text("sk-proj-••••••••••••••••••••••••")
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.82))
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color(red: 0.19, green: 0.82, blue: 0.35))
                                }
                                .padding(.horizontal, 12)
                                .frame(height: 42)
                                .background(Color.black.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            }
                        }
                        .frame(height: 126)

                        MarketingCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Label("Available Models", systemImage: "cpu.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)

                                MarketingModelRow(name: "gpt-5.5", detail: "Best for complex coding and long-running work", selected: true, tools: true, vision: true)
                                MarketingModelRow(name: "gpt-5.4", detail: "Strong everyday coding model", tools: true, vision: true)
                                MarketingModelRow(name: "gpt-5.4-mini", detail: "Fast and cost-efficient", tools: true, vision: false)
                                MarketingModelRow(name: "gpt-5.3-codex", detail: "Coding-optimized model", tools: true, vision: false)
                            }
                        }
                    }
                }

                MarketingPluginStrip()
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(red: 0.092, green: 0.098, blue: 0.116))
        }
    }
}

private struct MarketingSettingsSidebarRow: View {
    let title: String
    let icon: String
    var selected = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).frame(width: 18)
            Text(title)
            Spacer()
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(selected ? .white : .white.opacity(0.68))
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(selected ? Color(red: 0.49, green: 0.44, blue: 1.00).opacity(0.26) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct MarketingProviderRow: View {
    let name: String
    let detail: String
    var selected = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(selected ? Color(red: 0.49, green: 0.44, blue: 1.00) : Color.white.opacity(0.14))
                .frame(width: 26, height: 26)
                .overlay {
                    Text(String(name.prefix(1)))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .frame(height: 44)
        .background(selected ? Color(red: 0.49, green: 0.44, blue: 1.00).opacity(0.20) : Color.black.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct MarketingModelRow: View {
    let name: String
    let detail: String
    var selected = false
    var tools = false
    var vision = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selected ? Color(red: 0.19, green: 0.82, blue: 0.35) : .secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if tools {
                MarketingCapabilityPill(text: "Tools")
            }
            if vision {
                MarketingCapabilityPill(text: "Vision")
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .frame(height: 48)
        .background(selected ? Color(red: 0.49, green: 0.44, blue: 1.00).opacity(0.18) : Color.black.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct MarketingCapabilityPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color(red: 0.49, green: 0.44, blue: 1.00))
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(Color(red: 0.49, green: 0.44, blue: 1.00).opacity(0.16))
            .clipShape(Capsule())
    }
}

private struct MarketingPluginStrip: View {
    var body: some View {
        MarketingCard {
            HStack(spacing: 14) {
                Label("Enabled Plugins", systemImage: "puzzlepiece.extension")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                ForEach(["Editor", "Agent Chat", "Terminal", "Database", "Disk", "Device"], id: \.self) { plugin in
                    Text(plugin)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.84))
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
        }
        .frame(height: 72)
    }
}

#Preview("06 Model Settings") {
    MarketingScreenshot06ModelSettings()
}
