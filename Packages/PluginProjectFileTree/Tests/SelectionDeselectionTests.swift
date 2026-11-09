import AppKit
import Foundation
import Testing

@testable import PluginProjectFileTree

/// 回归 #1102：Cmd 点击已选项只触发 AppKit 反选回调，自定义选中集合不会移除该路径。
@MainActor
@Test("Cmd 取消选中后自定义选择与发送目标只剩剩余项")
func commandDeselectRemovesPathFromSelection() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("lumi-file-tree-deselect-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    for name in ["a.txt", "b.txt"] {
        try "".write(to: root.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    let controller = FileTreeCollectionViewController()
    controller.loadViewIfNeeded()
    controller.setProjectRoot(root.path)
    try await waitUntil(timeout: 2) {
        controller.selectionState.visiblePaths.count == 3
    }

    let first = root.appendingPathComponent("a.txt")
    let second = root.appendingPathComponent("b.txt")
    controller.selectionState.handleTap(
        url: first, isDirectory: false, modifiers: [], onToggleExpand: {}
    )
    controller.selectionState.handleTap(
        url: second, isDirectory: false, modifiers: .command, onToggleExpand: {}
    )
    #expect(controller.selectionState.selectedPaths.count == 2)

    // 行顺序为：项目根 0、a.txt 1、b.txt 2；AppKit 已把 a 从原生选中集合移除。
    let nativeSelection = StubSelectionCollectionView()
    nativeSelection.stubbedSelectionIndexPaths = [IndexPath(item: 2, section: 0)]
    controller.collectionView(
        nativeSelection,
        didDeselectItemsAt: [IndexPath(item: 1, section: 0)]
    )

    let remaining = PathFormatter.normalizedFilePath(second)
    #expect(controller.selectionState.selectedPaths == [remaining])
    #expect(
        controller.selectionState.actionTargets(for: second).map(\.lastPathComponent)
            == ["b.txt"]
    )
}

@MainActor
@Test("反选回调中仍处于原生选中集合的行不会被移除")
func deselectCallbackKeepsRowStillSelectedNatively() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("lumi-file-tree-deselect-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    for name in ["a.txt", "b.txt"] {
        try "".write(to: root.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    let controller = FileTreeCollectionViewController()
    controller.loadViewIfNeeded()
    controller.setProjectRoot(root.path)
    try await waitUntil(timeout: 2) {
        controller.selectionState.visiblePaths.count == 3
    }

    let first = root.appendingPathComponent("a.txt")
    let second = root.appendingPathComponent("b.txt")
    controller.selectionState.handleTap(
        url: first, isDirectory: false, modifiers: [], onToggleExpand: {}
    )
    controller.selectionState.handleTap(
        url: second, isDirectory: false, modifiers: .command, onToggleExpand: {}
    )
    let selectedBefore = controller.selectionState.selectedPaths

    let nativeSelection = StubSelectionCollectionView()
    nativeSelection.stubbedSelectionIndexPaths = [
        IndexPath(item: 1, section: 0),
        IndexPath(item: 2, section: 0),
    ]
    controller.collectionView(
        nativeSelection,
        didDeselectItemsAt: [IndexPath(item: 1, section: 0)]
    )

    #expect(controller.selectionState.selectedPaths == selectedBefore)
}

private final class StubSelectionCollectionView: NSCollectionView {
    var stubbedSelectionIndexPaths: Set<IndexPath> = []

    override var selectionIndexPaths: Set<IndexPath> {
        get { stubbedSelectionIndexPaths }
        set { stubbedSelectionIndexPaths = newValue }
    }
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
