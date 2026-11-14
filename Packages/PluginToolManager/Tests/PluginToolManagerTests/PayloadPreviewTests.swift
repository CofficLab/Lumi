import Foundation
import Testing
@testable import PluginToolManager

/// 大载荷有界预览的截断决策（issue #1303）。
///
/// 详情视图默认只布局前 `limit` 个字符，避免把数 MB 的工具结果一次性交给
/// SwiftUI 在主线程布局。这些用例钉住截断边界与「不遍历整段」的语义。
@Suite("PayloadPreview")
struct PayloadPreviewTests {
    @Test("短于上限的载荷完整渲染且不标记截断")
    func shortValueIsNotTruncated() {
        let preview = PayloadPreview.make("hello", limit: 100)
        #expect(preview.text == "hello")
        #expect(preview.isTruncated == false)
    }

    @Test("恰好等于上限的载荷完整渲染且不标记截断")
    func exactLimitIsNotTruncated() {
        let value = String(repeating: "a", count: 100)
        let preview = PayloadPreview.make(value, limit: 100)
        #expect(preview.text == value)
        #expect(preview.isTruncated == false)
    }

    @Test("超过上限的载荷只渲染前缀并标记截断")
    func longValueIsTruncatedToPrefix() {
        let value = String(repeating: "a", count: 10_000)
        let preview = PayloadPreview.make(value, limit: 100)
        #expect(preview.text.count == 100)
        #expect(preview.text == String(repeating: "a", count: 100))
        #expect(preview.isTruncated == true)
    }

    @Test("空载荷渲染为空且不标记截断")
    func emptyValueIsNotTruncated() {
        let preview = PayloadPreview.make("", limit: 100)
        #expect(preview.text.isEmpty)
        #expect(preview.isTruncated == false)
    }

    @Test("上限为 0 时非空载荷渲染为空但标记截断")
    func zeroLimitTruncatesNonEmpty() {
        let preview = PayloadPreview.make("abc", limit: 0)
        #expect(preview.text.isEmpty)
        #expect(preview.isTruncated == true)
    }

    @Test("负上限被钳制为 0，不会崩溃")
    func negativeLimitIsClamped() {
        let preview = PayloadPreview.make("abc", limit: -5)
        #expect(preview.text.isEmpty)
        #expect(preview.isTruncated == true)
    }

    @Test("按字符（字素簇）截断，多字节与 emoji 不被切碎")
    func truncationCountsGraphemeClusters() {
        // 每个 emoji 是一个字素簇但占多个 UTF-8/UTF-16 码元。
        let value = String(repeating: "👍🏽", count: 50)
        let preview = PayloadPreview.make(value, limit: 10)
        #expect(preview.text.count == 10)
        #expect(preview.text == String(repeating: "👍🏽", count: 10))
        #expect(preview.isTruncated == true)
    }

    @Test("默认上限与增量是正数且增量大于上限")
    func limitsAreSane() {
        #expect(PayloadPreview.initialLimit > 0)
        #expect(PayloadPreview.increment > 0)
        #expect(PayloadPreview.increment > PayloadPreview.initialLimit)
    }
}