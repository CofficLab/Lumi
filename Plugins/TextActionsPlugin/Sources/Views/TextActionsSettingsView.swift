import AppKit
import SwiftUI
import LumiUI
import LumiCoreKit

public struct TextActionsSettingsView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @StateObject private var manager = TextSelectionManager.shared
    @State private var isEnabled: Bool = false

    public var body: some View {
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
        .navigationTitle(LumiPluginLocalization.string("Text Actions", bundle: .module))
        .onAppear(perform: handleOnAppear)
        .onChange(of: isEnabled, handleEnabledChanged)
    }

    private var generalSettingsCard: some View {
        AppCard {
            AppSettingsSection(
                title: LumiPluginLocalization.string("General Settings", bundle: .module),
                spacing: 12
            ) {
                AppSettingsToggleRow(
                    LumiPluginLocalization.string("Enable Text Selection Menu", bundle: .module),
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
                        LumiPluginLocalization.string("Accessibility permission is required to detect text selection", bundle: .module)
                    )
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
                }

                AppButton(
                    LumiPluginLocalization.string("Open System Settings", bundle: .module),
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
                title: LumiPluginLocalization.string("Supported Actions", bundle: .module),
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
    public func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Event Handler

extension TextActionsSettingsView {
    public func handleOnAppear() {
        isEnabled = TextActionsPlugin.isEnabled
    }

    public func handleEnabledChanged(_ oldValue: Bool, _ newValue: Bool) {
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
