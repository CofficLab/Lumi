import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// 文件树多选状态，行为对齐 VS Code Explorer：
/// - 普通点击：单选并打开文件 / 展开文件夹
/// - Cmd+点击：切换选中项，不打开文件
/// - Shift+点击：在可见行范围内连续多选，不打开文件
@MainActor
final class SelectionState: ObservableObject {
    @Published private(set) var selectedPaths: Set<String> = []
    @Published private(set) var anchorPath: String?

    private var visibleOrder: [String] = []

    func isSelected(_ url: URL) -> Bool {
        selectedPaths.contains(normalizedPath(url))
    }

    var hasMultipleSelection: Bool {
        selectedPaths.count > 1
    }

    /// 右键菜单的操作目标：多选且当前节点在选中集合内时返回全部选中项，否则仅当前节点。
    func actionTargets(for contextURL: URL) -> [URL] {
        let contextPath = normalizedPath(contextURL)
        if selectedPaths.count > 1, selectedPaths.contains(contextPath) {
            return selectedURLsInVisibleOrder()
        }
        return [contextURL]
    }

    private func selectedURLsInVisibleOrder() -> [URL] {
        let ordered = visibleOrder.compactMap { path in
            selectedPaths.contains(path) ? URL(fileURLWithPath: path) : nil
        }
        if !ordered.isEmpty {
            return ordered
        }
        return selectedPaths.sorted().map { URL(fileURLWithPath: $0) }
    }

    func trackVisible(_ url: URL) {
        let path = normalizedPath(url)
        guard !visibleOrder.contains(path) else { return }
        visibleOrder.append(path)
    }

    func untrackVisible(_ url: URL) {
        let path = normalizedPath(url)
        visibleOrder.removeAll { $0 == path }
    }

    func resetVisibleOrder() {
        visibleOrder = []
    }

    func clearSelection() {
        selectedPaths = []
        anchorPath = nil
    }

    /// 编辑器当前文件变化时，将多选收束为单选。
    func syncFromEditorHighlight(_ url: URL) {
        let path = normalizedPath(url)
        selectedPaths = [path]
        anchorPath = path
    }

    func handleTap(
        url: URL,
        isDirectory: Bool,
        modifiers: ModifierFlags,
        onOpenFile: () -> Void,
        onToggleExpand: () -> Void
    ) {
        let path = normalizedPath(url)

        if modifiers.contains(.shift) {
            applyShiftSelection(path: path)
            return
        }

        if modifiers.contains(.command) {
            toggleSelection(path: path)
            anchorPath = path
            return
        }

        selectedPaths = [path]
        anchorPath = path

        if isDirectory {
            onToggleExpand()
        } else {
            onOpenFile()
        }
    }

    // MARK: - Private

    private func toggleSelection(path: String) {
        if selectedPaths.contains(path) {
            selectedPaths.remove(path)
        } else {
            selectedPaths.insert(path)
        }
    }

    private func applyShiftSelection(path: String) {
        guard let anchorPath,
              let anchorIndex = visibleOrder.firstIndex(of: anchorPath),
              let targetIndex = visibleOrder.firstIndex(of: path) else {
            selectedPaths = [path]
            anchorPath = path
            return
        }

        let lower = min(anchorIndex, targetIndex)
        let upper = max(anchorIndex, targetIndex)
        selectedPaths = Set(visibleOrder[lower...upper])
    }

    private func normalizedPath(_ url: URL) -> String {
        PathFormatter.normalizedFilePath(url)
    }
}

/// 跨平台修饰键抽象，便于单元测试。
struct ModifierFlags: OptionSet, Sendable {
    let rawValue: UInt

    static let command = ModifierFlags(rawValue: 1 << 0)
    static let shift = ModifierFlags(rawValue: 1 << 1)

    init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    #if canImport(AppKit)
    init(_ flags: NSEvent.ModifierFlags) {
        var value: UInt = 0
        if flags.contains(.command) { value |= Self.command.rawValue }
        if flags.contains(.shift) { value |= Self.shift.rawValue }
        self.init(rawValue: value)
    }

    static var currentClick: ModifierFlags {
        let flags = NSApp.currentEvent?
            .modifierFlags
            .intersection(.deviceIndependentFlagsMask) ?? []
        return ModifierFlags(flags)
    }
    #endif
}
