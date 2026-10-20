import CoreGraphics
import Testing
@testable import DisplayControlPlugin

// MARK: - Private Symbol Resolution Safety
//
// Issue #122: `DisplayServicesGetBrightness` / `DisplayServicesSetBrightness` 原本用
// `@_silgen_name` 声明，配合 `-undefined dynamic_lookup` 弱链接。框架未被进程加载时
// 符号地址为 NULL，调用即 SIGSEGV。
//
// 这些测试锁住修复后的契约：符号解析失败时**降级**而不是崩溃。

@Test("私有符号解析不会崩溃，缺失时降级为不可用")
func privateSymbolsDegradeGracefully() {
    // 解析过程本身不应崩溃。
    let getBrightness = PrivateDisplaySymbol.displayServicesGetBrightness
    let setBrightness = PrivateDisplaySymbol.displayServicesSetBrightness
    let createInfoDictionary = PrivateDisplaySymbol.coreDisplayCreateInfoDictionary
    let createAVService = PrivateDisplaySymbol.ioAVServiceCreateWithService
    let readI2C = PrivateDisplaySymbol.ioAVServiceReadI2C
    let writeI2C = PrivateDisplaySymbol.ioAVServiceWriteI2C

    // 在当前 macOS 上这些私有框架都存在，因此符号应当都能解析到。
    // 若某个系统版本缺失，对应项为 nil —— 两种情况都必须是"可安全调用"的状态。
    if let getBrightness {
        var value: Float = -1
        // 用一个不存在的 display id 调用：无论返回什么都不能崩溃。
        _ = getBrightness(999_999, &value)
    }
    if let setBrightness {
        _ = setBrightness(999_999, 0.5)
    }
    if let createInfoDictionary {
        _ = createInfoDictionary(999_999)
    }

    // 断言的是"调用没崩"，而不是符号是否存在 —— 两者都是合法状态。
    #expect(true)
}

@MainActor
@Test("DisplayService 在私有符号缺失时不会崩溃")
func displayServiceSurvivesMissingSymbols() {
    // 整条内置屏亮度路径都会经过 DisplayServices 私有符号。
    // 即使符号不可用，也必须安全返回而不是段错误。
    let service = DisplayService.shared
    service.refresh()

    // 刷新后不应崩溃，且显示器列表保持可读。
    #expect(service.displays.count >= 0)
}

@MainActor
@Test("DisplayService 对未知 display id 安全降级")
func displayServiceHandlesUnknownDisplayID() {
    let service = DisplayService.shared
    let unknownDisplayID: CGDirectDisplayID = 999_999

    service.refresh()

    // 未知 display id 不会出现在结果里。
    #expect(service.displays.allSatisfy { $0.id != unknownDisplayID })
}
