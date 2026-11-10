import AppKit
import Testing
@testable import EditorSource

/// `FindMethodPicker.updateNSView` 的子视图访问回归。
///
/// SwiftUI 会复用 `makeNSView` 返回的容器；`condensed` 在两帧之间变化时，
/// 容器的子视图数量可能与当前期望不一致。旧实现直接下标访问
/// `subviews[1]`/`subviews[2]`，数量不足时会越界 trap。
@MainActor
struct FindMethodPickerSubviewTests {
    @Test("子视图数量不足时不会越界并返回 nil")
    func missingSubviewsReturnNil() {
        let empty = NSView()
        #expect(FindMethodPicker.Subviews.imageView(at: 0, in: empty) == nil)
        #expect(FindMethodPicker.Subviews.imageView(at: 1, in: empty) == nil)
        #expect(FindMethodPicker.Subviews.imageView(at: 2, in: empty) == nil)

        let onlyPopup = NSView()
        onlyPopup.addSubview(NSPopUpButton())
        #expect(FindMethodPicker.Subviews.imageView(at: 1, in: onlyPopup) == nil)
        #expect(FindMethodPicker.Subviews.imageView(at: 2, in: onlyPopup) == nil)
    }

    @Test("序号在范围内时返回对应图片视图")
    func existingSubviewsAreResolved() {
        let container = NSView()
        container.addSubview(NSPopUpButton())
        let icon = NSImageView()
        let chevron = NSImageView()
        container.addSubview(icon)
        container.addSubview(chevron)

        #expect(FindMethodPicker.Subviews.imageView(at: 1, in: container) === icon)
        #expect(FindMethodPicker.Subviews.imageView(at: 2, in: container) === chevron)
        #expect(FindMethodPicker.Subviews.imageView(at: 3, in: container) == nil)
        #expect(FindMethodPicker.Subviews.imageView(at: -1, in: container) == nil)
    }

    @Test("序号指向非图片视图时返回 nil")
    func nonImageViewReturnsNil() {
        let container = NSView()
        container.addSubview(NSPopUpButton())
        container.addSubview(NSView())

        #expect(FindMethodPicker.Subviews.imageView(at: 0, in: container) == nil)
        #expect(FindMethodPicker.Subviews.imageView(at: 1, in: container) == nil)
    }
}
