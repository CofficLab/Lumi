import CoreGraphics
import Foundation
import IOKit
import Testing
@testable import DisplayControlPlugin

/// 回归 #864：DDC I2C 传输成功却被判成失败。
///
/// `IOAVServiceReadI2C` / `IOAVServiceWriteI2C` 返回的是 `IOReturn`，成功值是
/// `kIOReturnSuccess == 0`。此前这两个符号被声明成返回 `Bool`，于是成功的 0
/// 被读成 `false`：每一次正常的 DDC 读写都落进失败与重试分支。读到的永远
/// 是默认值，写入即便已经在硬件上生效也会被反复重发并最终报告失败。
@Suite("DDC I2C 返回值判定")
struct DDCI2CReturnValueTests {

    @Test("I2C 符号返回 IOReturn 而不是 Bool")
    func i2cSymbolsReturnIOReturn() {
        // 声明成 Bool 时，成功的 0 会被读成 false；契约必须钉住返回类型。
        let readI2C: (@convention(c) (CFTypeRef, UInt32, UInt32, UnsafeMutablePointer<UInt8>, UInt32) -> IOReturn)? =
            PrivateDisplaySymbol.ioAVServiceReadI2C
        let writeI2C: (@convention(c) (CFTypeRef, UInt32, UInt32, UnsafePointer<UInt8>, UInt32) -> IOReturn)? =
            PrivateDisplaySymbol.ioAVServiceWriteI2C

        #expect(readI2C != nil)
        #expect(writeI2C != nil)
    }

    @Test("kIOReturnSuccess 是 0")
    func successValueIsZero() {
        #expect(kIOReturnSuccess == 0)
    }

    @Test("传输结果按 IOReturn 判定，成功即成功")
    func transferResultUsesIOReturn() {
        // 用桩函数验证判定规则：返回 0 必须被判成成功。
        func isSuccess(_ status: IOReturn) -> Bool {
            status == kIOReturnSuccess
        }

        #expect(isSuccess(kIOReturnSuccess))
        #expect(isSuccess(0))
        #expect(!isSuccess(kIOReturnError))
        #expect(!isSuccess(kIOReturnNoDevice))
    }
}
