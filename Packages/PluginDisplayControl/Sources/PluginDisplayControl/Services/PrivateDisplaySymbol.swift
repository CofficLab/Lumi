import CoreGraphics
import Darwin
import Foundation
import IOKit
import LumiLoggingKit

// MARK: - Private API Symbol Resolution
//
// 这些符号全部来自 Apple 的私有框架，没有公开头文件。直接用 `@_silgen_name`
// 声明时，链接器采用 `-undefined dynamic_lookup` 弱链接：**只要对应框架没有被
// 进程加载，符号地址就是 NULL，调用即 SIGSEGV**。
//
// 实证（macOS 27.0.1）：
//
//     dlsym(dlopen(NULL, RTLD_LAZY), "DisplayServicesGetBrightness")  → 0x0
//     dlsym(dlopen(nil, RTLD_LAZY), "CoreDisplay_DisplayCreateInfoDictionary") → 0x0
//     dlsym(dlopen(nil, RTLD_LAZY), "IOAVServiceCreateWithService")      → 0x0
//
// 而显式 `dlopen` 对应框架后立刻可取到：
//
//     dlsym(dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY),
//           "DisplayServicesGetBrightness")  → 0x1a8f364d8
//
// 因此统一改为「显式 dlopen 框架 + dlsym 取符号」，取不到就降级为不可用，
// 而不是跳进 NULL 地址。
//
// - Note: 解析出来的函数指针在框架卸载后即失效，因此这里**不调用 `dlclose`**。
//   这三个框架都位于 dyld 共享缓存中，本就常驻进程，不会被真正卸载。

/// 私有符号表：框架路径 + 符号名 → 函数指针。
///
/// 全部在首次访问时解析并缓存（`static let` 天然懒加载且线程安全）。
enum PrivateDisplaySymbol {
    // MARK: Signatures

    typealias DisplayServicesGetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    typealias DisplayServicesSetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32
    typealias CoreDisplayCreateInfoDictionary = @convention(c) (CGDirectDisplayID) -> CFDictionary?
    typealias IOAVServiceCreateWithService = @convention(c) (UnsafeRawPointer?, io_service_t) -> UnsafeRawPointer?
    typealias IOAVServiceReadI2C = @convention(c) (CFTypeRef, UInt32, UInt32, UnsafeMutablePointer<UInt8>, UInt32) -> Bool
    typealias IOAVServiceWriteI2C = @convention(c) (CFTypeRef, UInt32, UInt32, UnsafePointer<UInt8>, UInt32) -> Bool

    // MARK: Framework Locations

    private enum Framework {
        static let displayServices = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        static let coreDisplay = "/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay"
        static let ioKit = "/System/Library/Frameworks/IOKit.framework/IOKit"
    }

    // MARK: Symbols

    /// `DisplayServicesGetBrightness` — 读取内置屏亮度。
    static let displayServicesGetBrightness: DisplayServicesGetBrightness? = {
        guard let symbol = lookup(Framework.displayServices, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(symbol, to: DisplayServicesGetBrightness.self)
    }()

    /// `DisplayServicesSetBrightness` — 写入内置屏亮度。
    static let displayServicesSetBrightness: DisplayServicesSetBrightness? = {
        guard let symbol = lookup(Framework.displayServices, "DisplayServicesSetBrightness") else { return nil }
        return unsafeBitCast(symbol, to: DisplayServicesSetBrightness.self)
    }()

    /// `CoreDisplay_DisplayCreateInfoDictionary` — 读取显示器信息字典（含产品名）。
    ///
    /// 遵循 Core Foundation 的 "Create" 规则：返回 +1 持有的 `CFDictionary` 或 NULL。
    static let coreDisplayCreateInfoDictionary: CoreDisplayCreateInfoDictionary? = {
        guard let symbol = lookup(Framework.coreDisplay, "CoreDisplay_DisplayCreateInfoDictionary") else { return nil }
        return unsafeBitCast(symbol, to: CoreDisplayCreateInfoDictionary.self)
    }()

    /// `IOAVServiceCreateWithService` — 由 IOKit 服务创建 AV service。
    ///
    /// 遵循 Core Foundation 的 "Create" 规则：返回 +1 持有的 `CFTypeRef` 或 NULL。
    /// allocator 参数应传 NULL（`kCFAllocatorDefault` 在 macOS 上是 nil，语义才是"用默认"）。
    static let ioAVServiceCreateWithService: IOAVServiceCreateWithService? = {
        guard let symbol = lookup(Framework.ioKit, "IOAVServiceCreateWithService") else { return nil }
        return unsafeBitCast(symbol, to: IOAVServiceCreateWithService.self)
    }()

    /// `IOAVServiceReadI2C` — 读取 AV service 的 I2C 数据。
    static let ioAVServiceReadI2C: IOAVServiceReadI2C? = {
        guard let symbol = lookup(Framework.ioKit, "IOAVServiceReadI2C") else { return nil }
        return unsafeBitCast(symbol, to: IOAVServiceReadI2C.self)
    }()

    /// `IOAVServiceWriteI2C` — 向 AV service 写入 I2C 数据。
    static let ioAVServiceWriteI2C: IOAVServiceWriteI2C? = {
        guard let symbol = lookup(Framework.ioKit, "IOAVServiceWriteI2C") else { return nil }
        return unsafeBitCast(symbol, to: IOAVServiceWriteI2C.self)
    }()

    // MARK: Resolution

    /// 打开框架并解析符号。取不到时记 warning 并返回 `nil`，调用方据此降级。
    ///
    /// - Note: 失败通常源于系统版本不提供该框架，属于稳定状态，记一次日志即可。
    private static func lookup(_ frameworkPath: String, _ symbolName: String) -> UnsafeRawPointer? {
        guard let handle = dlopen(frameworkPath, RTLD_LAZY) else {
            DisplayService.logger.warning(
                "\(DisplayService.t)DDC: cannot load framework \(frameworkPath, privacy: .public) — symbol \(symbolName, privacy: .public) unavailable"
            )
            return nil
        }

        guard let symbol = dlsym(handle, symbolName) else {
            DisplayService.logger.warning(
                "\(DisplayService.t)DDC: symbol \(symbolName, privacy: .public) not found — feature unavailable"
            )
            return nil
        }
        return UnsafeRawPointer(symbol)
    }
}
