import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// 文件树多选状态，行为对齐 VS Code Explorer：
/// - 普通点击：单选并打开文件 / 展开文件夹
/// - Cmd+点击：切换选中项，不打开文件
/// - Shift+点击：在可见行范围内连续多选，不打开文件
@MainActor
public final class SelectionState: ObservableObject {
    public init() {}

    @Published private(set) var selectedPaths: Set<String> = []
    @Published private(set) var anchorPath: String?

    /// 闪烁高亮路径：定位到文件时触发，触发后自动清除
    @Published public var flashPath: String?

    /// 可见路径的有序数组（保持插入顺序）
    private var visibleOrder: [String] = []
    /// 路径到索引的映射（用于 O(1) 查找）
    private var visibleOrderIndex: [String: Int] = [:]

    /// 闪烁任务，新触发时取消旧的
    private var flashTask: Task<Void, Never>?

    public func isSelected(_ url: URL) -> Bool {
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
        guard visibleOrderIndex[path] == nil else { return }
        visibleOrderIndex[path] = visibleOrder.count
        visibleOrder.append(path)
    }

    func untrackVisible(_ url: URL) {
        let path = normalizedPath(url)
        guard let index = visibleOrderIndex[path] else { return }
        
        // 从字典中移除
        visibleOrderIndex.removeValue(forKey: path)
        
        // 从数组中移除
        visibleOrder.remove(at: index)
        
        // 更新后续元素的索引
        for i in index..<visibleOrder.count {
            visibleOrderIndex[visibleOrder[i]] = i
        }
    }

    func resetVisibleOrder() {
        visibleOrder = []
        visibleOrderIndex = [:]
    }

    public func clearSelection() {
        selectedPaths = []
        anchorPath = nil
    }

    /// 编辑器当前文件变化时，将多选收束为单选。
    public func syncFromEditorHighlight(_ url: URL) {
        let path = normalizedPath(url)
        selectedPaths = [path]
        anchorPath = path
    }

    public func handleTap(
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
              let anchorIndex = visibleOrderIndex[anchorPath],
              let targetIndex = visibleOrderIndex[path] else {
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

    /// 触发闪烁高亮效果
    /// - Parameters:
    ///   - url: 要闪烁的文件路径
    ///   - duration: 闪烁持续时间（毫秒）
    public func triggerFlash(for url: URL, duration: TimeInterval = 0.8) {
        let path = normalizedPath(url)

        // 取消之前的闪烁任务
        flashTask?.cancel()

        // 设置闪烁路径
        flashPath = path

        // 启动闪烁任务，在指定时间后清除
        flashTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if self?.flashPath == path {
                    self?.flashPath = nil
                }
            }
        }
    }
}

/// 跨平台修饰键抽象，便于单元测试。
public struct ModifierFlags: OptionSet, Sendable {
    public let rawValue: UInt

    public static let command = ModifierFlags(rawValue: 1 << 0)
    public static let shift = ModifierFlags(rawValue: 1 << 1)

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    #if canImport(AppKit)
    public init(_ flags: NSEvent.ModifierFlags) {
        var value: UInt = 0
        if flags.contains(.command) { value |= Self.command.rawValue }
        if flags.contains(.shift) { value |= Self.shift.rawValue }
        self.init(rawValue: value)
    }

    public static var currentClick: ModifierFlags {
        let flags = NSApp.currentEvent?
            .modifierFlags
            .intersection(.deviceIndependentFlagsMask) ?? []
        return ModifierFlags(flags)
    }
    #endif
}