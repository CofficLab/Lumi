import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

enum ComputerUsePermissionService {
    static var hasScreenRecordingPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    static var hasAccessibilityPermission: Bool {
        let options = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    @MainActor
    static func requestScreenRecordingPermission() {
        CGRequestScreenCaptureAccess()
    }

    @MainActor
    static func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options),
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @MainActor
    static func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }

    /// 打开系统设置的「辅助功能」面板。
    ///
    /// 与 `requestAccessibilityPermission` 的区别：后者会触发系统的授权弹窗
    /// （`AXIsProcessTrustedWithOptions(prompt: true)`），只在应用尚未被
    /// 用户拉黑时才会出现；本方法**总是**跳到系统设置面板，让用户能直接
    /// 勾选 Lumi。
    @MainActor
    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
