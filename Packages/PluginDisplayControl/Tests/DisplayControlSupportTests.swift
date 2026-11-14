import Foundation
import Testing

@testable import DisplayControlPlugin

/// 回归 #240：DDC 传输通道存在被当成「每个 VCP 控制都可用」。
///
/// 一台支持 DDC 亮度的显示器可能并不支持音量/对比度 VCP。只有具体 VCP 读到值
/// 或有历史存储值才是该控制能力的证据；`hasDDCService` 本身不能替代逐控制检测。
@Suite("Display control 能力判定")
struct DisplayControlSupportTests {

    @Test("DDC service alone must not enable a control without per-control evidence (#240)")
    func ddcServiceAloneDoesNotEnableControl() {
        for control in [DisplayControlKind.brightness, .volume, .contrast] {
            #expect(!DisplayService.isControlSupported(
                control, isBuiltIn: false, appleBrightness: nil,
                ddcValue: nil, storedValue: nil, hasDDCService: true
            ))
        }
    }

    @Test("a successful VCP read enables the control (#240)")
    func liveVCPReadEnablesControl() {
        for control in [DisplayControlKind.brightness, .volume, .contrast] {
            #expect(DisplayService.isControlSupported(
                control, isBuiltIn: false, appleBrightness: nil,
                ddcValue: 50, storedValue: nil, hasDDCService: false
            ))
        }
    }

    @Test("a stored historical value enables the control without a live read (#240)")
    func storedValueEnablesControlWithoutLiveRead() {
        for control in [DisplayControlKind.brightness, .volume, .contrast] {
            #expect(DisplayService.isControlSupported(
                control, isBuiltIn: false, appleBrightness: nil,
                ddcValue: nil, storedValue: 40, hasDDCService: false
            ))
        }
    }

    @Test("built-in display only supports brightness backed by Apple evidence (#240)")
    func builtInOnlySupportsBrightnessWithAppleEvidence() {
        #expect(DisplayService.isControlSupported(
            .brightness, isBuiltIn: true, appleBrightness: 0.5,
            ddcValue: nil, storedValue: nil, hasDDCService: false
        ))
        #expect(!DisplayService.isControlSupported(
            .brightness, isBuiltIn: true, appleBrightness: nil,
            ddcValue: nil, storedValue: nil, hasDDCService: false
        ))
        for control in [DisplayControlKind.volume, .contrast] {
            #expect(!DisplayService.isControlSupported(
                control, isBuiltIn: true, appleBrightness: 0.5,
                ddcValue: 50, storedValue: 40, hasDDCService: true
            ))
        }
    }
}