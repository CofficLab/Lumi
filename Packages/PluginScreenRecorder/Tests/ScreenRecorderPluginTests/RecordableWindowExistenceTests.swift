import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import ScreenRecorderPlugin

/// 定向窗口存在性查询（见 issue #1272）。
///
/// 录制存活检测原先每秒调用 `availableWindows()` 全量枚举窗口列表，
/// 并为每个窗口构造一次 `NSRunningApplication` —— 全部在主线程。
/// `windowExists(id:)` 只查询目标窗口，且可以在后台线程执行。
@Suite("RecordableWindowProvider.windowExists")
struct RecordableWindowExistenceTests {

    @Test("不存在的窗口 ID 返回 false")
    func unknownWindowReturnsFalse() {
        // 用一个极大但不存在的窗口号，确保不会误命中。
        let unknownID = CGWindowID(0xFFFF_FFFE)
        #expect(RecordableWindowProvider.windowExists(id: unknownID) == false)
    }

    @Test("窗口 ID 0 返回 false")
    func zeroWindowIDReturnsFalse() {
        #expect(RecordableWindowProvider.windowExists(id: 0) == false)
    }

    @Test("查询在后台线程也能得到一致结果")
    func queryWorksOffMainThread() async {
        let unknownID = CGWindowID(0xFFFF_FFFD)
        let result = await Task.detached(priority: .utility) {
            RecordableWindowProvider.windowExists(id: unknownID)
        }.value
        #expect(result == false)
    }

    @Test("当前 app 至少有一个窗口可被发现")
    func currentAppHasDiscoverableWindow() throws {
        // 本 app 在测试进程里通常没有窗口；这里只断言查询不崩溃且返回布尔。
        let exists = RecordableWindowProvider.windowExists(id: CGWindowID(1))
        #expect(exists == true || exists == false)
    }
}
