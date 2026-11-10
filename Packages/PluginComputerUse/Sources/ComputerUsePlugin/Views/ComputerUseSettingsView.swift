import AppKit
import LumiUI
import SwiftUI

/// Computer Use 的设置页。
///
/// 现在只剩**系统权限**一项：屏幕录制与辅助功能。
///
/// 应用白名单区块已删除。应用访问权现在由会话的自动化等级决定
/// （A3 完全放行、A2 会话内授权一次），不需要用户逐个 App 手工维护；
/// 设置页再放一张表只会让用户以为这里才是控制点。
@MainActor
struct ComputerUseSettingsView: View {
    @ObservedObject private var state: ComputerUseSettingsState
    @LumiTheme private var theme
    @State private var screenRecordingAllowed = false
    @State private var accessibilityAllowed = false
    @State private var revision = 0

    init(state: ComputerUseSettingsState) {
        self._state = ObservedObject(wrappedValue: state)
    }

    var body: some View {
        PluginSettingsScaffold(
            title: pluginLocalization.string("Computer Use"),
            subtitle: pluginLocalization.string("Grant system permissions so Lumi can see and operate application windows."),
            showHeader: false,
            scrollsContent: false
        ) {
            VStack(alignment: .leading, spacing: 14) {
                permissionsSection
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.bottom, 16)
        .id(revision)
        .onAppear(perform: refresh)
        .onChange(of: state.revision) { _ in refresh() }
    }

    private var permissionsSection: some View {
        AppSettingSection(
            title: pluginLocalization.string("System Permissions"),
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                permissionRow(
                    title: pluginLocalization.string("Screen Recording"),
                    detail: pluginLocalization.string("Allows Lumi to capture the selected application window."),
                    granted: screenRecordingAllowed,
                    icon: "rectangle.dashed.and.paperclip"
                ) {
                    ComputerUsePermissionService.requestScreenRecordingPermission(); refresh()
                }
                Divider()
                    .padding(.vertical, 8)
                permissionRow(
                    title: pluginLocalization.string("Accessibility"),
                    detail: pluginLocalization.string("Allows Lumi to click, type, scroll, and navigate."),
                    granted: accessibilityAllowed,
                    icon: "accessibility"
                ) {
                    ComputerUsePermissionService.requestAccessibilityPermission(); refresh()
                }
            }
        }
    }

    private func permissionRow(title: String, detail: String, granted: Bool, icon: String, request: @escaping () -> Void) -> some View {
        AppSettingRow(
            title: title,
            description: detail,
            icon: icon,
            titleSuffix: {
                Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(granted ? theme.success : theme.warning)
            }
        ) {
            if granted {
                EmptyView()
            } else {
                AppButton(pluginLocalization.string("Grant Access"), style: .secondary, size: .small, action: request)
            }
        }
    }

    private func refresh() {
        screenRecordingAllowed = ComputerUsePermissionService.hasScreenRecordingPermission
        accessibilityAllowed = ComputerUsePermissionService.hasAccessibilityPermission
        revision += 1
    }
}
