import SwiftUI
import Testing
@testable import LumiUI

/// 跨平台 API 可用性约束。
///
/// `HoverContainers.swift` 与 `AppSplitDivider.swift` 曾经被整体包在
/// `#if canImport(AppKit)` 里，导致它们声明的 public API
/// （`StatusBarHoverContainer` / `HoverableContainerView` /
/// `SidebarToolbarHoverContainer` / `sidebarToolbarButton` /
/// `sidebarToolbarPopover` / `appSplitDivider` / `AppSplitDividerEdge` /
/// `AppSplitDividerResizeTarget`）在 iOS 与 visionOS 上**整个消失**。
///
/// 这些用例确保 API 在三个平台上都被正确导出。
struct LumiCrossPlatformAPITests {

    @Test("Hover 容器在所有平台可用")
    @MainActor
    func hoverContainersAreAvailableOnEveryPlatform() {
        _ = StatusBarHoverContainer { Text("content") }
        _ = StatusBarHoverContainer(detailView: Text("detail")) { Text("content") }
        _ = HoverableContainerView(detailView: Text("detail")) { Text("content") }
        _ = SidebarToolbarHoverContainer(id: "id") { Text("content") }
        _ = SidebarToolbarHoverContainer(detailView: Text("detail"), id: "id") { Text("content") }
    }

    @Test("侧边栏工具栏助手在所有平台可用")
    @MainActor
    func sidebarToolbarHelpersAreAvailableOnEveryPlatform() {
        _ = sidebarToolbarButton(tooltip: "tip", action: {}) { Text("content") }
        _ = sidebarToolbarPopover(detailView: Text("detail")) { Text("content") }
    }

    @Test("分隔线修饰器在所有平台可用")
    @MainActor
    func splitDividerModifierIsAvailableOnEveryPlatform() {
        _ = Text("pane").appSplitDivider(.leading)
        _ = Text("pane").appSplitDivider(.trailing)
        _ = Text("pane").appSplitDivider(.bottom)
        _ = Text("pane").appSplitDivider(.leading, onResize: nil)
        _ = Text("pane").appSplitDivider(.leading, restingShadow: false, onResize: nil)
        _ = Text("pane").appSplitDivider(
            .leading,
            initialPosition: 120,
            initialTrailingSize: 240,
            restingShadow: true,
            resizeTarget: .trailing,
            onResize: { _ in }
        )
    }

    @Test("分隔线枚举在所有平台可用")
    func splitDividerEnumsAreAvailableOnEveryPlatform() {
        _ = AppSplitDividerEdge.leading
        _ = AppSplitDividerEdge.trailing
        _ = AppSplitDividerEdge.bottom
        _ = AppSplitDividerResizeTarget.leading
        _ = AppSplitDividerResizeTarget.trailing
    }
}
