import SwiftUI

/// Selectable model row for LLM provider settings.
public struct AppSettingsModelRow: View {
    @LumiTheme private var theme

    let model: String
    let isDefault: Bool
    let defaultLabel: String
    let supportsVision: Bool?
    let supportsTools: Bool?
    let supportsTTS: Bool?
    let onTap: (() -> Void)?

    public init(
        model: String,
        isDefault: Bool,
        defaultLabel: String = "默认",
        supportsVision: Bool? = nil,
        supportsTools: Bool? = nil,
        supportsTTS: Bool? = nil,
        onTap: @escaping () -> Void
    ) {
        self.model = model
        self.isDefault = isDefault
        self.defaultLabel = defaultLabel
        self.supportsVision = supportsVision
        self.supportsTools = supportsTools
        self.supportsTTS = supportsTTS
        self.onTap = onTap
    }

    /// 只读展示，不可点击设为默认。
    public init(
        model: String,
        supportsVision: Bool? = nil,
        supportsTools: Bool? = nil,
        supportsTTS: Bool? = nil
    ) {
        self.model = model
        self.isDefault = false
        self.defaultLabel = "默认"
        self.supportsVision = supportsVision
        self.supportsTools = supportsTools
        self.supportsTTS = supportsTTS
        self.onTap = nil
    }

    public var body: some View {
        Group {
            if let onTap {
                AppListRow(isSelected: isDefault, action: onTap) {
                    rowContent
                }
            } else {
                rowContent
                    .padding(.horizontal, AppUI.Spacing.md)
                    .padding(.vertical, AppUI.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text(model)
                    .font(.appBody)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if isDefault {
                    AppTag(defaultLabel, style: .accent)
                }
            }

            if hasCapabilities {
                HStack(spacing: 6) {
                    if let supportsVision {
                        capabilityBadge(
                            title: supportsVision ? "Image" : "Text",
                            systemImage: supportsVision ? "photo" : "text.bubble"
                        )
                    }
                    if let supportsTools, supportsTools {
                        capabilityBadge(title: "Tools", systemImage: "wrench.and.screwdriver")
                    }
                    if let supportsTTS, supportsTTS {
                        capabilityBadge(title: "TTS", systemImage: "waveform")
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var hasCapabilities: Bool {
        supportsVision != nil || (supportsTools == true) || (supportsTTS == true)
    }

    @ViewBuilder
    private func capabilityBadge(title: String, systemImage: String) -> some View {
        AppTag(title, systemImage: systemImage, style: .subtle)
            .help(title)
    }
}
