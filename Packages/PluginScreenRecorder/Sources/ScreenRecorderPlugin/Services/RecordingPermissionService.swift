import AppKit
import AVFoundation
import CoreGraphics
import Foundation

/// 录制相关权限的预检与申请。
///
/// 屏幕录制权限与 `ComputerUsePermissionService` 同源（`CGPreflight/RequestScreenCaptureAccess`）；
/// 麦克风权限走 `AVAudioApplication`（macOS 14+）。所有「申请」方法都在主线程触发系统弹窗
/// 或打开系统设置深链，便于在确认流程中调用。
public enum RecordingPermissionService {

    // MARK: - Screen Recording

    /// 是否已拥有屏幕录制权限（不弹窗）。
    public static var hasScreenRecordingPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// 请求屏幕录制权限（触发系统弹窗；用户仍需在系统设置里手动开启开关）。
    @MainActor
    public static func requestScreenRecordingPermission() {
        CGRequestScreenCaptureAccess()
    }

    /// 打开「系统设置 → 隐私与安全性 → 屏幕录制」深链。
    @MainActor
    public static func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Microphone

    /// 是否已拥有麦克风权限（不弹窗）。
    public static var hasMicrophonePermission: Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    /// 请求麦克风权限（触发系统弹窗）。结果以闭包返回，便于在调用处决定后续行为。
    @MainActor
    public static func requestMicrophonePermission(_ completion: @escaping @Sendable (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { granted in
            Task { @MainActor in completion(granted) }
        }
    }

    /// 打开「系统设置 → 隐私与安全性 → 麦克风」深链。
    @MainActor
    public static func openMicrophoneSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else { return }
        NSWorkspace.shared.open(url)
    }
}
