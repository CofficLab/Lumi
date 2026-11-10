import Foundation
import Testing
@testable import ProviderRootView

/// `ContentFooterHeight` 的边界夹取与 `FileContentFooterHeightStore` 的持久化契约。
@Suite("ContentFooterHeight")
@MainActor
struct ContentFooterHeightTests {

    // MARK: - Value Clamping

    @Test("标准高度使用 100/280/无限最大值")
    func standardValues() {
        #expect(ContentFooterHeight.standard.minHeight == 100)
        #expect(ContentFooterHeight.standard.idealHeight == 280)
        #expect(ContentFooterHeight.standard.maxHeight.isInfinite)
    }

    @Test("负的最小高度被夹取为 0")
    func negativeMinIsClamped() {
        let height = ContentFooterHeight(minHeight: -50, idealHeight: 100, maxHeight: 500)

        #expect(height.minHeight == 0)
        #expect(height.idealHeight == 100)
    }

    @Test("理想高度低于最小值时被夹取到最小值")
    func idealBelowMinClamps() {
        let height = ContentFooterHeight(minHeight: 200, idealHeight: 50, maxHeight: 500)

        #expect(height.idealHeight == 200)
    }

    @Test("理想高度高于最大值时被夹取到最大值")
    func idealAboveMaxClamps() {
        let height = ContentFooterHeight(minHeight: 100, idealHeight: 900, maxHeight: 500)

        #expect(height.idealHeight == 500)
    }

    @Test("最大值小于最小值时被提升到最小值")
    func maxBelowMinIsRaised() {
        let height = ContentFooterHeight(minHeight: 300, idealHeight: 200, maxHeight: 100)

        #expect(height.maxHeight == 300)
        #expect(height.idealHeight == 300)
    }

    @Test("非有限输入被安全处理")
    func nonFiniteInputsAreSafe() {
        let height = ContentFooterHeight(
            minHeight: .infinity,
            idealHeight: .nan,
            maxHeight: .infinity
        )

        #expect(height.minHeight == 0)
        #expect(height.idealHeight == 0)
        #expect(height.maxHeight.isInfinite)
    }

    @Test("withIdealHeight 重新夹取理想高度")
    func withIdealHeightReclamps() {
        let base = ContentFooterHeight(minHeight: 100, idealHeight: 280, maxHeight: 500)

        let within = base.withIdealHeight(320)
        #expect(within.idealHeight == 320)

        let tooLow = base.withIdealHeight(10)
        #expect(tooLow.idealHeight == 100)

        let tooHigh = base.withIdealHeight(900)
        #expect(tooHigh.idealHeight == 500)
    }

    @Test("clamped 对任意高度夹取到区间内")
    func clampedBounds() {
        let height = ContentFooterHeight(minHeight: 100, idealHeight: 280, maxHeight: 500)

        #expect(height.clamped(50) == 100)
        #expect(height.clamped(280) == 280)
        #expect(height.clamped(750) == 500)
    }

    // MARK: - File Store

    @Test("高度持久化并跨实例恢复")
    func heightPersistsAcrossInstances() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FooterHeightStore-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("footer-heights.plist")
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = FileContentFooterHeightStore(fileURL: fileURL)
        first.saveHeight(320, ownerID: "plugin.a")

        let second = FileContentFooterHeightStore(fileURL: fileURL)
        #expect(second.loadHeight(ownerID: "plugin.a") == 320)
        #expect(second.loadHeight(ownerID: "plugin.b") == nil)
    }

    @Test("空 owner、非正数与非有限值不被保存")
    func invalidValuesAreRejected() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FooterHeightGuard-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("footer-heights.plist")
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = FileContentFooterHeightStore(fileURL: fileURL)
        store.saveHeight(320, ownerID: "")
        store.saveHeight(0, ownerID: "plugin.a")
        store.saveHeight(-10, ownerID: "plugin.a")
        store.saveHeight(.nan, ownerID: "plugin.a")

        #expect(store.loadHeight(ownerID: "plugin.a") == nil)
        #expect(store.loadHeight(ownerID: "") == nil)
    }

    @Test("删除高度后读取为 nil 且不影响其他条目")
    func removeHeightClearsOnlyTarget() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FooterHeightRemove-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("footer-heights.plist")
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = FileContentFooterHeightStore(fileURL: fileURL)
        store.saveHeight(200, ownerID: "plugin.a")
        store.saveHeight(300, ownerID: "plugin.b")

        store.removeHeight(ownerID: "plugin.a")
        store.removeHeight(ownerID: "missing")

        #expect(store.loadHeight(ownerID: "plugin.a") == nil)
        #expect(store.loadHeight(ownerID: "plugin.b") == 300)
    }
}
