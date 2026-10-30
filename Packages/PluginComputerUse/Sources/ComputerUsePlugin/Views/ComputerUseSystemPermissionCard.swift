import AppKit
import LumiUI
import SwiftUI

/// Computer Use 系统权限提示卡。
///
/// 展示缺失的系统权限，并提供两个直达入口：
/// - 「打开系统设置」→ 跳到 macOS 对应隐私面板；
/// - 「打开 Lumi 设置」→ 跳到 Lumi 设置的 Computer Use 入口。
///
/// 权限状态在应用重新激活时刷新：用户在系统设置里勾选后回到 Lumi，
/// 卡片会立刻从「缺少权限」变成「已授权，可重试」。
struct ComputerUseSystemPermissionCard: View {
    @LumiTheme private var theme

    let request: ComputerUseSystemPermissionRequest

    @State private var isGranted = false

    var body: some View {
        AppCard(
            style: .subtle,
            cornerRadius: 10,
            padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12),
            showShadow: false
        ) {
            VStack(alignment: .leading, spacing: 10) {
                header

                Text(request.operation)
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)

                if isGranted {
                    grantedFooter
                } else {
                    buttons
                }
            }
        }
        // - Important: 必须显式 `children: .contain`。否则 SwiftUI 会把卡片当作
        //   一个整体元素，把容器上的 identifier 覆盖到所有后代，子元素最终统统
        //   报告同一个 id，UI 测试无法按标识符区分两个按钮
        //   （与 `ToolApprovalPendingView` 同一坑）。
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(ComputerUseSystemPermissionAccessibility.card)
        .onAppear(perform: refresh)
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            refresh()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(isGranted ? theme.success : theme.error)
            Text(titleText)
                .font(.appCaption)
                .foregroundColor(theme.textPrimary)
                .accessibilityIdentifier(ComputerUseSystemPermissionAccessibility.title)

            Spacer(minLength: 0)
        }
    }

    /// 标题文案随权限状态切换。
    ///
    /// 已授权后仍显示「需要 XX 权限」是错的——用户已经点完开关回来了，
    /// 卡片必须如实反映最新状态。
    private var titleText: String {
        let template = isGranted
            ? pluginLocalization.string("{permission} permission granted")
            : pluginLocalization.string("{permission} permission is required")
        return template.replacingOccurrences(
            of: "{permission}",
            with: request.permission.displayName
        )
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            AppButton(
                request.permission.openSystemSettingsTitle,
                systemImage: "gearshape.fill",
                style: .primary,
                size: .small,
                fillsWidth: true
            ) {
                openSystemSettings()
            }
            .accessibilityIdentifier(ComputerUseSystemPermissionAccessibility.button(request.permission))

            AppButton(
                pluginLocalization.string("Open Lumi Settings"),
                systemImage: "slider.horizontal.3",
                style: .secondary,
                size: .small,
                fillsWidth: true
            ) {
                ComputerUseSystemPermissionBridge.shared.openLumiSettings()
            }
            .accessibilityIdentifier(ComputerUseSystemPermissionAccessibility.lumiSettings)
        }
    }

    private var grantedFooter: some View {
        Text(pluginLocalization.string("Permission granted. You can retry this operation."))
            .font(.appMicro)
            .foregroundColor(theme.textSecondary)
    }

    /// 跳到 macOS 对应的隐私面板。
    private func openSystemSettings() {
        switch request.permission {
        case .accessibility:
            ComputerUsePermissionService.openAccessibilitySettings()
        case .screenRecording:
            ComputerUsePermissionService.openScreenRecordingSettings()
        }
    }

    /// 刷新权限状态。
    private func refresh() {
        let granted: Bool
        switch request.permission {
        case .accessibility:
            granted = ComputerUsePermissionService.hasAccessibilityPermission
        case .screenRecording:
            granted = ComputerUsePermissionService.hasScreenRecordingPermission
        }
        if granted != isGranted {
            isGranted = granted
        }
    }
}
