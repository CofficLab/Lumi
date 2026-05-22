import SwiftUI
import LLMKit
import LumiUI

/// 供应商选择按钮组件
struct ProviderButton: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let provider: LLMProviderInfo
    let isSelected: Bool
    let action: () -> Void

    init(provider: LLMProviderInfo, isSelected: Bool, action: @escaping () -> Void) {
        self.provider = provider
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            AppSettingsRow(isSelected: isSelected, horizontalPadding: 12, verticalPadding: 6) {
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
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(provider.displayName)
        .accessibilityHint("切换 LLM 供应商")
    }

    private var rowForegroundColor: Color {
        isSelected ? theme.textPrimary : theme.textSecondary
    }

    private var linkIconColor: Color {
        rowForegroundColor.opacity(isSelected ? 0.7 : 0.55)
    }
}
