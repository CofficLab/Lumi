import AppKit
import SwiftUI
import LumiUI

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
}

// MARK: - View

extension TextActionsSettingsView {
    private var generalSettingsCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "General Settings", table: "TextActions"))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                Toggle(isOn: $isEnabled) {
                    Text(String(localized: "Enable Text Selection Menu", table: "TextActions"))
                }

                if !manager.isPermissionGranted {
                    permissionWarningView
                }
            }
        }
    }

    private var permissionWarningView: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color(hex: "FF9F0A"))
            Text(
                String(
                    localized: "Accessibility permission is required to detect text selection",
                    table: "TextActions"
                )
            )
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
            GlassButton(title: LocalizedStringKey(String(localized: "Open System Settings")), style: .secondary) {
                openAccessibilitySettings()
            }
            .frame(maxWidth: 180)
        }
        .padding(.top, 4)
    }

    private var supportedActionsCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "Supported Actions", table: "TextActions"))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                VStack(spacing: 4) {
                    ForEach(TextActionType.allCases) { action in
                        actionRow(for: action)
                    }
                }
            }
        }
    }

    private func actionRow(for action: TextActionType) -> some View {
        GlassRow {
            HStack {
                Image(systemName: action.icon)
                    .frame(width: 20)
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                Text(action.title)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                Spacer()
                Image(systemName: "checkmark")
                    .foregroundColor(Color(hex: "30D158"))
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

// MARK: - Setter

extension TextActionsSettingsView {
    @MainActor
    func setIsEnabled(_ value: Bool) {
        isEnabled = value
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

// MARK: - Preview

#Preview {
    TextActionsSettingsView()
        .frame(width: 400, height: 600)
}
