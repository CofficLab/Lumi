import Foundation
import AppKit
import CodeEditSourceEditor
import CodeEditTextView
import SwiftUI

/// 文本变更协调器
/// 监听 CodeEditSourceEditor 的文本变更，通知 LumiEditorState 触发自动保存
final class LumiEditorCoordinator: TextViewCoordinator {
    
    /// 弱引用状态管理器
    private weak var state: LumiEditorState?
    
    init(state: LumiEditorState) {
        self.state = state
    }
    
    // MARK: - TextViewCoordinator
    
    nonisolated func textViewDidChangeText(controller: TextViewController) {
        let state = self.state
        // 延迟到下一个 RunLoop，避免 "Modifying state during view update"
        DispatchQueue.main.async {
            if state == nil {
                print("⚠️ [LumiEditor] LumiEditorCoordinator: state is nil!")
            }
            state?.notifyContentChanged()
        }
    }
    
    nonisolated func prepareCoordinator(controller: TextViewController) {}
    
    nonisolated func destroy() {
        state = nil
    }
}

/// 光标位置协调器
/// 监听光标位置变化，更新行号/列号信息
final class LumiCursorCoordinator: TextViewCoordinator {
    
    private weak var state: LumiEditorState?
    
    init(state: LumiEditorState) {
        self.state = state
    }
    
    // MARK: - TextViewCoordinator
    
    nonisolated func textViewDidChangeSelection(controller: TextViewController) {
        let state = self.state
        let positions = controller.cursorPositions
        var line = 1
        var column = 1
        if let first = positions.first {
            line = first.start.line
            column = first.start.column
        }
        
        // 延迟到下一个 RunLoop，避免 "Modifying state during view update"
        DispatchQueue.main.async {
            state?.cursorLine = line
            state?.cursorColumn = column
        }
    }
    
    nonisolated func prepareCoordinator(controller: TextViewController) {}
    
    nonisolated func controllerDidAppear(controller: TextViewController) {
        if controller.isEditable && controller.isSelectable {
            controller.view.window?.makeFirstResponder(controller.textView)
        }
    }
    
    nonisolated func destroy() {
        state = nil
    }
}

// MARK: - Context Menu Coordinator

/// 右键菜单协调器
/// 在编辑器的右键菜单中注入「添加到对话」操作
///
/// **方案原理：**
/// CodeEditTextView 的 `TextView` 重写了 `menu(for:)`，每次右键时动态创建
/// 一个只含 Cut/Copy/Paste 的新 NSMenu。直接设置 `textView.menu` 属性无效，
/// 因为 AppKit 调用的是 `menu(for:)` 而非读取 `self.menu`。
///
/// 因此我们通过 ObjC runtime 的 `class_replaceMethod` 替换 textView 实例所属类
/// 的 `menu(for:)` 实现。新实现先调用原始方法获取标准菜单，再往其中插入自定义项。
final class LumiContextMenuCoordinator: TextViewCoordinator {

    private weak var state: LumiEditorState?

    init(state: LumiEditorState) {
        self.state = state
    }

    nonisolated func prepareCoordinator(controller: TextViewController) {}

    nonisolated func controllerDidAppear(controller: TextViewController) {
        guard let textView = controller.textView else { return }
        let state = self.state

        Task { @MainActor [weak state] in
            guard let state else { return }
            LumiContextMenuManager.shared.register(textView: textView, state: state)
        }
    }

    nonisolated func destroy() {
        state = nil
    }
}

// MARK: - Context Menu Manager

/// 管理所有 textView 实例的右键菜单注入
///
/// 使用全局单例 + associated object 的方式，在 swizzle 后的 `menu(for:)` 中
/// 通过 textView 实例查找对应的 helper 来注入自定义菜单项。
@MainActor
final class LumiContextMenuManager {

    static let shared = LumiContextMenuManager()

    /// 关联对象 key：标记是否已经 swizzle 过该类
    private static let swizzledKey = malloc(1)!

    /// 关联对象 key：存储每个 textView 实例对应的 helper
    private static let helperKey = malloc(1)!

    private init() {}

    /// 注册 textView，执行 swizzle（仅首次）并绑定 helper
    func register(textView: TextView, state: LumiEditorState) {
        let targetClass = object_getClass(textView)!

        // 确保这个类只 swizzle 一次
        if objc_getAssociatedObject(targetClass, Self.swizzledKey) == nil {
            objc_setAssociatedObject(targetClass, Self.swizzledKey, true, .OBJC_ASSOCIATION_RETAIN)
            swizzleMenuForClass(targetClass)
        }

        // 为每个 textView 实例绑定 helper
        if objc_getAssociatedObject(textView, Self.helperKey) == nil {
            let helper = LumiContextMenuHelper(textView: textView, state: state)
            objc_setAssociatedObject(textView, Self.helperKey, helper, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    /// 获取某个 textView 实例关联的 helper
    static func helperForTextView(_ textView: TextView) -> LumiContextMenuHelper? {
        objc_getAssociatedObject(textView, helperKey) as? LumiContextMenuHelper
    }

    // MARK: - Swizzle

    /// 替换指定类的 `menu(for:)` 方法
    private func swizzleMenuForClass(_ targetClass: AnyClass) {
        let selector = #selector(NSView.menu(for:))

        guard let originalMethod = class_getInstanceMethod(targetClass, selector) else { return }
        let originalIMP = method_getImplementation(originalMethod)

        // 新实现：先调用原始方法拿到菜单，再由 helper 注入自定义项
        let block: @convention(block) (TextView, NSEvent) -> NSMenu? = { textView, event in
            // 调用原始 menu(for:)
            typealias OriginalIMPType = @convention(c) (AnyObject, Selector, NSEvent) -> NSMenu?
            let originalMenu = unsafeBitCast(originalIMP, to: OriginalIMPType.self)(textView, selector, event)

            guard let menu = originalMenu else { return nil }

            // 在主线程查找 helper 并注入自定义项
            if let helper = LumiContextMenuManager.helperForTextView(textView) {
                helper.injectCustomItems(into: menu)
            }

            return menu
        }

        let newIMP = imp_implementationWithBlock(block)
        class_replaceMethod(targetClass, selector, newIMP, "@@:@@")
    }
}

// MARK: - Context Menu Helper

/// 每个 textView 实例对应一个 helper，负责注入自定义菜单项
@MainActor
final class LumiContextMenuHelper: NSObject {

    private weak var textView: TextView?
    private weak var state: LumiEditorState?
    private var currentTarget: LumiContextMenuTarget?

    init(textView: TextView, state: LumiEditorState) {
        self.textView = textView
        self.state = state
    }

    /// 在右键菜单中注入自定义项
    func injectCustomItems(into menu: NSMenu) {
        let addTitle = String(localized: "Add to Chat", table: "LumiEditor")

        // 先清除之前可能注入的项（防止重复）
        while let idx = menu.items.firstIndex(where: { $0.title == addTitle }) {
            menu.removeItem(at: idx)
        }
        while let idx = menu.items.firstIndex(where: { $0.tag == 999 && $0.isSeparatorItem }) {
            menu.removeItem(at: idx)
        }

        // 检查是否有选区
        guard let textView,
              textView.selectionManager.textSelections.contains(where: { !$0.range.isEmpty }) else {
            return
        }

        let state = self.state
        let target = LumiContextMenuTarget { [weak self] in
            guard let self, let textView = self.textView, let state else { return }
            Self.performAddToChat(textView: textView, state: state)
        }
        self.currentTarget = target

        let menuItem = NSMenuItem(
            title: addTitle,
            action: #selector(LumiContextMenuTarget.addToChatClicked),
            keyEquivalent: ""
        )
        menuItem.target = target
        menuItem.image = NSImage(systemSymbolName: "bubble.left.and.text.bubble.right", accessibilityDescription: nil)

        let separator = NSMenuItem.separator()
        separator.tag = 999

        // 插入到菜单最顶部
        menu.insertItem(separator, at: 0)
        menu.insertItem(menuItem, at: 0)
    }

    // MARK: - Add to Chat Action

    private static func performAddToChat(textView: TextView, state: LumiEditorState) {
        let selections = textView.selectionManager.textSelections
        guard let firstSelection = selections.first, !firstSelection.range.isEmpty else { return }

        let range = firstSelection.range
        let fullText = textView.string
        guard range.location + range.length <= fullText.count else { return }
        let nsRange = NSRange(location: range.location, length: range.length)
        let selectedText = (fullText as NSString).substring(with: nsRange)
        guard !selectedText.isEmpty else { return }

        let textBeforeStart = (fullText as NSString).substring(with: NSRange(location: 0, length: range.location))
        let textBeforeEnd = (fullText as NSString).substring(with: NSRange(location: 0, length: range.location + range.length))

        let startLine = textBeforeStart.filter { $0 == "\n" }.count + 1
        let startColumn: Int
        if let lastNL = textBeforeStart.lastIndex(of: "\n") {
            startColumn = textBeforeStart.distance(from: textBeforeStart.index(after: lastNL), to: textBeforeStart.endIndex) + 1
        } else {
            startColumn = textBeforeStart.count + 1
        }

        let endLine = textBeforeEnd.filter { $0 == "\n" }.count + 1
        let endColumn: Int
        if let lastNL = textBeforeEnd.lastIndex(of: "\n") {
            endColumn = textBeforeEnd.distance(from: textBeforeEnd.index(after: lastNL), to: textBeforeEnd.endIndex) + 1
        } else {
            endColumn = textBeforeEnd.count + 1
        }

        let filePath = state.relativeFilePath

        let locationText: String
        if startLine == endLine && startColumn == endColumn {
            locationText = "\(filePath):\(startLine):\(startColumn)"
        } else {
            locationText = "\(filePath):\(startLine):\(startColumn)-\(endLine):\(endColumn)"
        }

        NotificationCenter.postAddToChat(text: locationText)
    }
}

// MARK: - Menu Target

final class LumiContextMenuTarget: NSObject {
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    @objc func addToChatClicked() {
        action()
    }
}
