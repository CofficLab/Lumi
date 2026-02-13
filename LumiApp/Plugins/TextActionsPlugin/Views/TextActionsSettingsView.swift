import AppKit
import SwiftUI

struct TextActionsSettingsView: View {
    @StateObject private var manager = TextSelectionManager.shared
    @AppStorage("TextActionsEnabled") private var isEnabled = false

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
                            Text("General Settings", tableName: "TextActions")
                                .font(DesignTokens.Typography.title3)
                                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                            Toggle(isOn: $isEnabled) {
                                Text("Enable Text Selection Menu", tableName: "TextActions")
                            }
                                .onChange(of: isEnabled) { _, newValue in
                                    if newValue {
                                        manager.startMonitoring()
                                        _ = TextActionMenuController.shared
                                    } else {
                                        manager.stopMonitoring()
                                    }
                                }

                            if !manager.isPermissionGranted {
                                HStack(spacing: DesignTokens.Spacing.sm) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(DesignTokens.Color.semantic.warning)
                                    Text("Accessibility permission is required to detect text selection", tableName: "TextActions")
                                        .font(DesignTokens.Typography.caption1)
                                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                                    GlassButton(title: LocalizedStringKey(String(localized: "Open System Settings", table: "TextActions")), style: .secondary) {
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
                            Text("Supported Actions", tableName: "TextActions")
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
                                                .foregroundColor(DesignTokens.Color.semantic.primary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(DesignTokens.Spacing.md)
            }
        }
        .onAppear {
            manager.checkPermission()
            if isEnabled {
                manager.startMonitoring()
                _ = TextActionMenuController.shared
            }
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .withNavigation(TextActionsPlugin.id)
        .hideTabPicker()
        .inRootView()
        .withDebugBar()
}
