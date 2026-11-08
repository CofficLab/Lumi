import AppKit
import CoreGraphics
import Foundation

/// Screen Recording TCC 权限检测 + 用户引导
///
/// `App.entitlements` 已声明 `com.apple.security.screen-capture`,但首次调用
/// 截图 API 时系统仍会弹一次授权窗口。
@MainActor
public enum ScreenCapturePermissionPrompter {
    /// 检查权限，未授权时直接触发系统授权请求。
    ///
    /// `CGPreflightScreenCaptureAccess()` 只做查询，权限处于「未决定」时同样返回
    /// false 且不会弹窗；因此必须补一次 `CGRequestScreenCaptureAccess()` 才能真正
    /// 拉起系统授权。该调用在「已拒绝」时不再弹窗，直接返回 false，交由调用方
    /// 弹 NSAlert 引导用户去 System Settings。
    ///
    /// 两个系统调用以闭包注入，便于单元测试覆盖分支而不触碰真实 TCC。
    public static func ensurePermission(
        preflight: () -> Bool = { CGPreflightScreenCaptureAccess() },
        request: () -> Bool = { CGRequestScreenCaptureAccess() }
    ) -> Bool {
        if preflight() { return true }
        return request()
    }

    /// 弹出 NSAlert 告知用户需要权限,并可选打开 System Settings
    public static func presentAlert(openSettingsOnConfirm: Bool = true) {
        let alert = NSAlert()
        alert.messageText = String(
            localized: "Screen Recording Permission Required",
            bundle: .module
        )
        alert.informativeText = String(
            localized: "Lumi needs Screen Recording permission to capture screenshots. Please grant access in System Settings, then try again.",
            bundle: .module
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Open System Settings", bundle: .module))
        alert.addButton(withTitle: String(localized: "Cancel", bundle: .module))

        guard openSettingsOnConfirm else { return }

        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}