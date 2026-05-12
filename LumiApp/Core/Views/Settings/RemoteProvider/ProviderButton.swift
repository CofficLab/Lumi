import SwiftUI
import LumiUI

/// 供应商选择按钮组件
struct ProviderButton: View {
    let provider: LLMProviderInfo
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(provider.displayName)
                    .font(.system(size: 12, weight: .regular))

                Spacer(minLength: 0)

                if let websiteURL = provider.websiteURL,
                   let url = URL(string: websiteURL) {
                    Button(action: {
                        NSWorkspace.shared.open(url)
                    }) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 10))
                            .foregroundColor(linkIconColor)
                    }
                    .buttonStyle(.plain)
                    .help(websiteURL)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .appSurface(
                style: .custom(backgroundColor),
                cornerRadius: 6
            )
            .foregroundColor(foregroundColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(provider.displayName)
        .accessibilityHint("双击切换 LLM 供应商")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var backgroundColor: Color {
        if isSelected { return Color(hex: "7C6FFF") }
        if isHovered { return Color.white.opacity(0.12) }
        return Color.white.opacity(0.05)
    }

    private var foregroundColor: Color {
        if isSelected { return .white }
        return Color.adaptive(light: "6B6B7B", dark: "EBEBF5")
    }

    private var linkIconColor: Color {
        if isSelected { return .white.opacity(0.7) }
        return Color.adaptive(light: "6B6B7B", dark: "EBEBF5").opacity(0.5)
    }
}
