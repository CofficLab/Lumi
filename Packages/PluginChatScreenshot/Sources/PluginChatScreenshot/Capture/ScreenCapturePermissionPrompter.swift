import AppKit
import CoreGraphics
import Foundation

/// Screen Recording TCC 权限检测 + 用户引导
///
/// `App.entitlements` 已声明 `com.apple.security.screen-capture`,但首次调用
/// 截图 API 时系统仍会弹一次授权窗口。若用户拒绝或从未授权,
/// `CGPreflightScreenCaptureAccess` 返回 false;此时应弹 NSAlert 引导用户
/// 去 System Settings 手动授权。
@MainActor
public enum ScreenCapturePermissionPrompter {
    /// 检查当前是否已授权 Screen Recording(可同步调用,无副作用)
    public static func ensurePermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// 触发系统授权弹窗(异步请求授权)
    ///
    /// 调用后,系统会弹出 macOS 自带的授权窗口。返回时**不能**假设权限已就绪,
    /// 应再次调 `ensurePermission()` 校验。
    public static func requestPermission() {
        CGRequestScreenCaptureAccess()
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