import AppKit
import Foundation
import ProviderToast
import Testing

@testable import PluginProjectFileTree

/// 回归 #1109：多选右键 Move to Trash 必须处理 `actionTargets(for:)` 的全部目标，
/// 而不是只删除右键项。
@MainActor
struct FileTreeBatchDeleteTests {
    private let first = URL(fileURLWithPath: "/tmp/lumi-trash-selection/a.txt")
    private let second = URL(fileURLWithPath: "/tmp/lumi-trash-selection/b.txt")

    @Test("批量删除会处理全部选中目标")
    func batchTrashProcessesEveryTarget() {
        var visited: [URL] = []

        let result = FileTreeFacade.trashItemsReporting(at: [first, second]) { url in
            visited.append(url)
            return true
        }

        #expect(visited.map(\.lastPathComponent) == ["a.txt", "b.txt"])
        #expect(result.trashedURLs.map(\.lastPathComponent) == ["a.txt", "b.txt"])
        #expect(result.failedURLs.isEmpty)
        #expect(!result.hasPartialFailure)
        #expect(result.totalCount == 2)
    }

    @Test("批量删除会保留失败项用于部分失败汇报")
    func batchTrashReportsPartialFailure() {
        let result = FileTreeFacade.trashItemsReporting(at: [first, second]) { url in
            url == self.first
        }

        #expect(result.trashedURLs == [first])
        #expect(result.failedURLs == [second])
        #expect(result.hasPartialFailure)
        #expect(result.totalCount == 2)
    }

    @Test("批量删除会跳过被选中目录的子路径")
    func batchTrashSkipsNestedTargets() {
        let directory = URL(fileURLWithPath: "/tmp/lumi-trash-selection/folder", isDirectory: true)
        let child = directory.appendingPathComponent("child.txt")
        var visited: [URL] = []

        let result = FileTreeFacade.trashItemsReporting(at: [directory, child]) { url in
            visited.append(url)
            return true
        }

        #expect(visited == [directory])
        #expect(result.totalCount == 1)
        #expect(result.failedURLs.isEmpty)
    }

    @Test("多选时 Move to Trash 菜单携带全部选中项")
    func deleteMenuCarriesEverySelectedTarget() async throws {
        let root = try makeTempProject(fileNames: ["a.txt", "b.txt"])
        defer { try? FileManager.default.removeItem(at: root) }

        let controller = FileTreeCollectionViewController()
        controller.loadViewIfNeeded()
        controller.setProjectRoot(root.path)
        try await waitUntil(timeout: 2) {
            controller.selectionState.visiblePaths.count == 3
        }

        let firstURL = root.appendingPathComponent("a.txt")
        let secondURL = root.appendingPathComponent("b.txt")
        controller.selectionState.handleTap(
            url: firstURL, isDirectory: false, modifiers: [], onToggleExpand: {}
        )
        controller.selectionState.handleTap(
            url: secondURL, isDirectory: false, modifiers: .command, onToggleExpand: {}
        )

        let menu = controller.buildMenu(for: firstURL, isDirectory: false)
        let deleteItem = try #require(menu.items.first {
            $0.title == pluginLocalization.string("Move to Trash")
        })
        let targets = try #require(deleteItem.representedObject as? [URL])

        #expect(targets.map(\.lastPathComponent) == ["a.txt", "b.txt"])
    }

    @Test("多选删除会移除全部目标的选择")
    func performDeleteTrashesEveryTarget() async throws {
        let root = try makeTempProject(fileNames: ["a.txt", "b.txt"])
        defer { try? FileManager.default.removeItem(at: root) }

        let controller = FileTreeCollectionViewController()
        controller.loadViewIfNeeded()
        controller.setProjectRoot(root.path)
        let recorder = RecordingToastProvider()
        controller.context = FileTreeContext(project: nil, conversationInput: nil, toast: recorder)
        try await waitUntil(timeout: 2) {
            controller.selectionState.visiblePaths.count == 3
        }

        let firstURL = root.appendingPathComponent("a.txt")
        let secondURL = root.appendingPathComponent("b.txt")
        controller.selectionState.handleTap(
            url: firstURL, isDirectory: false, modifiers: [], onToggleExpand: {}
        )
        controller.selectionState.handleTap(
            url: secondURL, isDirectory: false, modifiers: .command, onToggleExpand: {}
        )

        var received: [URL] = []
        controller.trashHandler = { urls in
            received = urls
            return FileTreeFacade.TrashBatchResult(trashedURLs: urls, failedURLs: [])
        }

        controller.performDelete(targets: controller.selectionState.actionTargets(for: firstURL))

        #expect(received.map(\.lastPathComponent) == ["a.txt", "b.txt"])
        #expect(controller.selectionState.selectedPaths.isEmpty)
        #expect(recorder.toasts.last?.style == .success)
    }

    @Test("部分失败时保留失败项的选择并给出警告")
    func performDeleteKeepsFailedTargetSelected() async throws {
        let root = try makeTempProject(fileNames: ["a.txt", "b.txt"])
        defer { try? FileManager.default.removeItem(at: root) }

        let controller = FileTreeCollectionViewController()
        controller.loadViewIfNeeded()
        controller.setProjectRoot(root.path)
        let recorder = RecordingToastProvider()
        controller.context = FileTreeContext(project: nil, conversationInput: nil, toast: recorder)
        try await waitUntil(timeout: 2) {
            controller.selectionState.visiblePaths.count == 3
        }

        let firstURL = root.appendingPathComponent("a.txt")
        let secondURL = root.appendingPathComponent("b.txt")
        controller.selectionState.handleTap(
            url: firstURL, isDirectory: false, modifiers: [], onToggleExpand: {}
        )
        controller.selectionState.handleTap(
            url: secondURL, isDirectory: false, modifiers: .command, onToggleExpand: {}
        )

        controller.trashHandler = { urls in
            FileTreeFacade.TrashBatchResult(
                trashedURLs: urls.filter { $0.lastPathComponent != "b.txt" },
                failedURLs: urls.filter { $0.lastPathComponent == "b.txt" }
            )
        }

        controller.performDelete(targets: controller.selectionState.actionTargets(for: firstURL))

        #expect(
            controller.selectionState.selectedPaths
                == [PathFormatter.normalizedFilePath(secondURL)]
        )
        #expect(recorder.toasts.last?.style == .warning)
        #expect(recorder.toasts.last?.detail?.contains("b.txt") == true)
    }

    private func makeTempProject(fileNames: [String]) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-file-tree-batch-delete-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for name in fileNames {
            try "".write(
                to: root.appendingPathComponent(name),
                atomically: true,
                encoding: .utf8
            )
        }
        return root
    }

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
}

@MainActor
private final class RecordingToastProvider: ToastProviding {
    private(set) var toasts: [LumiToast] = []

    func show(_ toast: LumiToast) {
        toasts.append(toast)
    }

    func presentError(title: String, message: String, sourceWindowID: String?) {}

    func dismissError() {}
}
