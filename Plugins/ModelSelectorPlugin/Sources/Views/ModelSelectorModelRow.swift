import LumiCoreKit
import LumiUI
import SwiftUI

struct ModelSelectorModelRow: View {
    @LumiTheme private var theme

    let provider: LumiLLMProviderInfo
    let model: String
    let isSelected: Bool
    let stat: ModelPerformanceStats?
    let onSelect: () -> Void

    init(
        provider: LumiLLMProviderInfo,
        model: String,
        isSelected: Bool,
        stat: ModelPerformanceStats? = nil,
        onSelect: @escaping () -> Void
    ) {
        self.provider = provider
        self.model = model
        self.isSelected = isSelected
        self.stat = stat
        self.onSelect = onSelect
    }

    // MARK: - Derived

    private var capabilities: LumiModelCapabilities? {
        provider.modelCapabilities[model]
    }

    var body: some View {
        AppListRow(isSelected: isSelected, action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(model)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.primary)
                    }

                    Spacer()

                    if let contextSize = provider.contextWindowSizes[model] {
                        AppTag(ModelSelectorFormatService.contextSize(contextSize), systemImage: "text.viewfinder")
                    }

                    if let stat, stat.avgTPS > 0 {
                        AppTag(ModelSelectorFormatService.tps(stat.avgTPS), systemImage: "speedometer")
                    }

                    if let stat, stat.sampleCount > 0 {
                        AppTag("\(stat.sampleCount)", systemImage: "bubble.left.and.bubble.right")
                    }
                }

                // MARK: - 能力 Badge
                if let capabilities {
                    HStack(spacing: 6) {
                        capabilityBadge(
                            title: capabilities.supportsVision ? "Image" : "Text",
                            systemImage: capabilities.supportsVision ? "photo" : "text.bubble"
                        )

                        if capabilities.supportsTools {
                            capabilityBadge(title: "Tools", systemImage: "wrench.and.screwdriver")
                        }

                        if capabilities.supportsTTS {
                            capabilityBadge(title: "TTS", systemImage: "waveform")
                        }

                        Spacer()
                    }
                } else {
                    HStack(spacing: 6) {
                        AppTag(provider.displayName)
                        AppTag(provider.id, systemImage: "cloud")
                        Spacer()
                    }
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
        }
    }

    // MARK: - Helper

    @ViewBuilder
    private func capabilityBadge(title: String, systemImage: String) -> some View {
        AppTag(title, systemImage: systemImage, style: .subtle)
            .help(title)
    }
}
