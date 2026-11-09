import AppKit
import Foundation
import Testing

@testable import PluginProjectFileTree

/// 回归 #1101：可见行顺序从未被登记，Shift 范围选择始终退化为单选。
@MainActor
@Test("Shift 点击选中 anchor 到目标之间的全部可见行")
func shiftClickSelectsEveryVisibleItemInRange() {
    let state = SelectionState()
    let first = URL(fileURLWithPath: "/Project/a.txt")
    let second = URL(fileURLWithPath: "/Project/b.txt")
    let third = URL(fileURLWithPath: "/Project/c.txt")
    state.updateVisibleOrder([first, second, third])

    state.handleTap(url: first, isDirectory: false, modifiers: [], onToggleExpand: {})
    state.handleTap(url: third, isDirectory: false, modifiers: .shift, onToggleExpand: {})

    let expected = Set([first, second, third].map { PathFormatter.normalizedFilePath($0) })
    #expect(state.selectedPaths == expected)
    #expect(
        state.actionTargets(for: third).map(\.lastPathComponent)
            == ["a.txt", "b.txt", "c.txt"]
    )
}

@MainActor
@Test("可见行顺序重建后按新范围选择，不包含已折叠行")
func visibleOrderUpdateDropsCollapsedItems() {
    let state = SelectionState()
    let first = URL(fileURLWithPath: "/Project/a.txt")
    let hidden = URL(fileURLWithPath: "/Project/b.txt")
    let third = URL(fileURLWithPath: "/Project/c.txt")

    state.updateVisibleOrder([first, hidden, third])
    state.updateVisibleOrder([first, third])

    state.handleTap(url: first, isDirectory: false, modifiers: [], onToggleExpand: {})
    state.handleTap(url: third, isDirectory: false, modifiers: .shift, onToggleExpand: {})

    let expected = Set([first, third].map { PathFormatter.normalizedFilePath($0) })
    #expect(state.selectedPaths == expected)
}

@MainActor
@Test("文件树快照会建立可见行顺序，Shift 选择可覆盖整个范围")
func controllerTracksVisibleOrderForShiftSelection() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("lumi-file-tree-selection-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    for name in ["a.txt", "b.txt", "c.txt"] {
        try "".write(to: root.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    let controller = FileTreeCollectionViewController()
    controller.loadViewIfNeeded()
    controller.setProjectRoot(root.path)

    try await waitUntil(timeout: 2) {
        controller.selectionState.visiblePaths.count == 4
    }

    let first = root.appendingPathComponent("a.txt")
    let second = root.appendingPathComponent("b.txt")
    let third = root.appendingPathComponent("c.txt")
    // 文件树包含项目根行，其后的三行应保持目录枚举顺序。
    let expectedOrder = [first, second, third].map { PathFormatter.normalizedFilePath($0) }
    #expect(Array(controller.selectionState.visiblePaths.suffix(3)) == expectedOrder)

    controller.selectionState.handleTap(
        url: first, isDirectory: false, modifiers: [], onToggleExpand: {}
    )
    controller.selectionState.handleTap(
        url: third, isDirectory: false, modifiers: .shift, onToggleExpand: {}
    )

    #expect(controller.selectionState.selectedPaths == Set(expectedOrder))
    #expect(
        controller.selectionState.actionTargets(for: third).map(\.lastPathComponent)
            == ["a.txt", "b.txt", "c.txt"]
    )
}

@MainActor
private func waitUntil(
    timeout: TimeInterval,
    _ condition: () -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        guard Date() < deadline else {
            Issue.record("等待超时（\(timeout)s）：条件未满足")
            return
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
}
