import CoreGraphics
import Foundation
import Testing
@testable import DisplayControlPlugin

/// 回归 #865：CoreDisplay 的 Create 规则字典每次刷新都泄漏。
///
/// `CoreDisplay_DisplayCreateInfoDictionary` 遵循 Core Foundation 的 "Create"
/// 规则，返回 +1 持有的字典。调用点若直接桥接成 Swift 字典而没有取走所有权，
/// 字典就不会被释放。插件每 5 秒刷新一次，于是字典实例持续累积。
///
/// 这些测试锁住修复后的契约：符号签名必须把所有权显式带出来（`Unmanaged`），
/// 并且取字典内容的入口必须把这份所有权平衡掉。
@Suite("CoreDisplay 字典所有权")
struct CoreDisplayInfoDictionaryOwnershipTests {

    @Test("符号签名用 Unmanaged 表达 Create 规则的所有权")
    func symbolSignatureCarriesOwnership() {
        // 裸 `CFDictionary?` 无法表达 +1 持有，调用点极易忘记释放。
        let createInfoDictionary = PrivateDisplaySymbol.coreDisplayCreateInfoDictionary
        #expect(createInfoDictionary != nil)

        // 用返回类型断言把契约钉住：必须是 `Unmanaged<CFDictionary>?`。
        let typed: (@convention(c) (CGDirectDisplayID) -> Unmanaged<CFDictionary>?)? = createInfoDictionary
        #expect(typed != nil)
    }

    @Test("取字典内容后所有权被平衡，实例不会持续累积")
    func takingTheValueReleasesTheDictionary() throws {
        guard let createInfoDictionary = PrivateDisplaySymbol.coreDisplayCreateInfoDictionary else {
            // 私有框架在部分系统上不可用：此时没有可测的行为。
            return
        }

        // 取一次 +1 的字典，立刻取走所有权。
        guard let unmanaged = createInfoDictionary(CGMainDisplayID()) else {
            return
        }
        let info = unmanaged.takeRetainedValue() as? [String: Any]
        #expect(info != nil)
    }

    @Test("反复读取显示器名称不累积未释放的字典")
    func repeatedDisplayNameDoesNotAccumulateDictionaries() {
        // 这条路径每 5 秒被刷新流程调用一次，是泄漏的实际发生点。
        let before = Self.currentAllocatedBytes()
        for _ in 0..<200 {
            _ = DisplayService.displayName(for: CGMainDisplayID(), isBuiltIn: true)
        }
        let after = Self.currentAllocatedBytes()

        // 允许一定的正常波动，但泄漏 200 个字典必然越过这个阈值。
        let growth = after - before
        #expect(growth < 8 * 1024 * 1024, "分配字节数增长了 \(growth) 字节，可能仍有泄漏")
    }

    // MARK: - Helpers

    /// 当前进程的已分配字节数（`task_info` 的 `phys_footprint`）。
    private static func currentAllocatedBytes() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), reboundPointer, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Int(info.phys_footprint)
    }
}
