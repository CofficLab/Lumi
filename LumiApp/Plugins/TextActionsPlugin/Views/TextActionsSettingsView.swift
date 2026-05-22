import AppKit
import SwiftUI
import LumiUI

struct TextActionsSettingsView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

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
                VStack(alignment: .leading, spacing: 16) {
                    generalSettingsCard
                    supportedActionsCard
                }
                .padding(24)
            }
        }
        .navigationTitle(String(localized: "Text Actions", table: "TextActions"))
        .onAppear(perform: handleOnAppear)
        .onChange(of: isEnabled, handleEnabledChanged)
    }

    private var generalSettingsCard: some View {
        AppCard {
            AppSettingsSection(
                title: String(localized: "General Settings", table: "TextActions"),
                spacing: 12
            ) {
                AppSettingsToggleRow(
                    String(localized: "Enable Text Selection Menu", table: "TextActions"),
                    systemImage: "text.cursor",
                    isOn: $isEnabled
                )

                if !manager.isPermissionGranted {
                    permissionWarningView
                }
            }
        }
    }

    private var permissionWarningView: some View {
        AppSettingsRow {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(theme.warning)
                    Text(
                        String(
                            localized: "Accessibility permission is required to detect text selection",
                            table: "TextActions"
                        )
                    )
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
                }

                AppButton(
                    String(localized: "Open System Settings", table: "TextActions"),
                    style: .secondary,
                    fillsWidth: true,
                    action: openAccessibilitySettings
                )
            }
        }
    }

    private var supportedActionsCard: some View {
        AppCard {
            AppSettingsSection(
                title: String(localized: "Supported Actions", table: "TextActions"),
                spacing: 6
            ) {
                ForEach(TextActionType.allCases) { action in
                    actionRow(for: action)
                }
            }
        }
    }

    private func actionRow(for action: TextActionType) -> some View {
        AppSettingsRow(verticalPadding: 6) {
            HStack(spacing: 12) {
                Image(systemName: action.icon)
                    .frame(width: 20)
                    .foregroundColor(theme.textSecondary)
                Text(action.title)
                    .font(.appBody)
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Image(systemName: "checkmark")
                    .foregroundColor(theme.success)
            }
        }
    }
}

// MARK: - Action

extension TextActionsSettingsView {
    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Event Handler

extension TextActionsSettingsView {
    func handleOnAppear() {
        isEnabled = TextActionsPlugin.isEnabled
    }

    func handleEnabledChanged(_ oldValue: Bool, _ newValue: Bool) {
        TextActionsPlugin.setEnabled(newValue)
        if newValue {
            manager.startMonitoring()
            _ = TextActionMenuController.shared
        } else {
            manager.stopMonitoring()
        }
    }
}

#Preview {
    TextActionsSettingsView()
        .inRootView()
        .frame(width: 400, height: 600)
}
