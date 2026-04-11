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
/// CodeEditTextView 的 `TextView` 重写了 `menu(for:)`，每次右键时动态创建
/// Cut/Copy/Paste 菜单。我们通过给 textView 创建自定义 `menu` 属性并设置
/// `NSMenuDelegate`，在 `menuNeedsUpdate` 中动态插入自定义菜单项。
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
            LumiContextMenuHelper.install(on: textView, state: state)
        }
    }
    
    nonisolated func destroy() {
        state = nil
    }
}

// MARK: - Context Menu Helper

/// 通过 NSView.menu 属性 + NSMenuDelegate 方式在右键菜单中添加自定义项
@MainActor
final class LumiContextMenuHelper: NSObject, NSMenuDelegate {
    
    private static let helperKey = malloc(1)!
    
    private weak var textView: TextView?
    private weak var state: LumiEditorState?
    private var currentTarget: LumiContextMenuTarget?
    
    private init(textView: TextView, state: LumiEditorState) {
        self.textView = textView
        self.state = state
    }
    
    static func install(on textView: TextView, state: LumiEditorState) {
        if objc_getAssociatedObject(textView, helperKey) is LumiContextMenuHelper { return }
        
        let helper = LumiContextMenuHelper(textView: textView, state: state)
        objc_setAssociatedObject(textView, helperKey, helper, .OBJC_ASSOCIATION_RETAIN)
        
        // 创建自定义菜单：包含标准编辑操作和自定义项
        let menu = NSMenu()
        menu.delegate = helper
        menu.autoenablesItems = true
        
        // 标准编辑操作（模拟 TextView.menu(for:) 中的 Cut/Copy/Paste）
        menu.addItem(NSMenuItem(title: "Cut", action: #selector(NSTextView.cut(_:)), keyEquivalent: "x"))
        menu.addItem(NSMenuItem(title: "Copy", action: #selector(NSTextView.copy(_:)), keyEquivalent: "c"))
        menu.addItem(NSMenuItem(title: "Paste", action: #selector(NSTextView.paste(_:)), keyEquivalent: "v"))
        
        // 设置 textView 的 menu 属性
        // 这会覆盖 TextView.menu(for:) 的行为
        textView.menu = menu
    }
    
    // MARK: - NSMenuDelegate
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        // 移除之前添加的「添加到对话」菜单项和分隔线
        let addTitle = String(localized: "Add to Chat", table: "LumiEditor")
        while let idx = menu.items.firstIndex(where: { $0.title == addTitle }) {
            menu.removeItem(at: idx)
        }
        // 移除通过 tag=999 标记的分隔线
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
