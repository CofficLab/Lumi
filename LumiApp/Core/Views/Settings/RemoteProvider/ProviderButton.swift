import SwiftUI
import LLMKit
import LumiUI

/// 供应商选择按钮组件
struct ProviderButton: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let provider: LLMProviderInfo
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    init(provider: LLMProviderInfo, isSelected: Bool, action: @escaping () -> Void) {
        self.provider = provider
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(provider.displayName)
                .font(.appCaption)
                .foregroundColor(rowForegroundColor)

            Spacer(minLength: 0)

            if let websiteURL = provider.websiteURL,
               let url = URL(string: websiteURL) {
                Button(action: {
                    NSWorkspace.shared.open(url)
                }) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.appMicro)
                        .foregroundColor(linkIconColor)
                }
                .buttonStyle(.plain)
                .help(websiteURL)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .appSurface(
            style: rowSurfaceStyle,
            cornerRadius: 8,
            borderColor: rowBorderColor,
            lineWidth: 1
        )
        .onTapGesture(perform: action)
        .accessibilityLabel(provider.displayName)
        .accessibilityHint("切换 LLM 供应商")
        .accessibilityAddTraits(.isButton)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }

    private var rowForegroundColor: Color {
        isSelected ? theme.textPrimary : theme.textSecondary
    }

    private var linkIconColor: Color {
        rowForegroundColor.opacity(isSelected ? 0.7 : 0.55)
    }

    private var rowSurfaceStyle: AppSurfaceStyle {
        if isSelected {
            return .listRowSelected
        }
        if isHovered {
            return .listRowHover
        }
        return .listRow
    }

    private var rowBorderColor: Color? {
        if isSelected {
            return theme.appSelectedBorder
        }
        if isHovered {
            return theme.appHoverBorder
        }
        return nil
    }
}
