import AppKit
import SwiftUI

struct TextActionsSettingsView: View {
    @StateObject private var manager = TextSelectionManager.shared
    @State private var isEnabled: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            TextActionPreviewView(isEnabled: isEnabled)
                .frame(maxWidth: .infinity)
                .frame(height: 200)

            GlassDivider()
                .frame(maxWidth: .infinity, maxHeight: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    MystiqueGlassCard {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            Text("General Settings")
                                .font(DesignTokens.Typography.title3)
                                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                            Toggle(isOn: $isEnabled) {
                                Text("Enable Text Selection Menu")
                            }

                            if !manager.isPermissionGranted {
                                HStack(spacing: DesignTokens.Spacing.sm) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(DesignTokens.Color.semantic.warning)
                                    Text("Accessibility permission is required to detect text selection")
                                        .font(DesignTokens.Typography.caption1)
                                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                                    GlassButton(title: LocalizedStringKey(String(localized: "Open System Settings")), style: .secondary) {
                                        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                                        NSWorkspace.shared.open(url)
                                    }
                                    .frame(maxWidth: 180)
                                }
                                .padding(.top, DesignTokens.Spacing.xs)
                            }
                        }
                    }

                    MystiqueGlassCard {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            Text("Supported Actions")
                                .font(DesignTokens.Typography.title3)
                                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                            VStack(spacing: DesignTokens.Spacing.xs) {
                                ForEach(TextActionType.allCases) { action in
                                    GlassRow {
                                        HStack {
                                            Image(systemName: action.icon)
                                                .frame(width: 20)
                                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                                            Text(action.title)
                                                .font(DesignTokens.Typography.body)
                                                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                                            Spacer()
                                            Image(systemName: "checkmark")
                                                .foregroundColor(DesignTokens.Color.semantic.success)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }
        }
        .navigationTitle(String(localized: "Text Actions", table: "TextActions"))
        .onAppear {
            isEnabled = TextActionsPlugin.isEnabled
        }
        .onChange(of: isEnabled) { _, newValue in
            TextActionsPlugin.setEnabled(newValue)
            if newValue {
                manager.startMonitoring()
                _ = TextActionMenuController.shared
            } else {
                manager.stopMonitoring()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TextActionsSettingsView()
        .frame(width: 400, height: 600)
}
