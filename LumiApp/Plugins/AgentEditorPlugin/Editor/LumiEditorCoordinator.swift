import Foundation
import AppKit
import CodeEditSourceEditor
import CodeEditTextView
import SwiftUI
import LanguageServerProtocol

/// 文本变更协调器
/// 监听 CodeEditSourceEditor 的文本变更，通知 LumiEditorState 触发自动保存
final class LumiEditorCoordinator: TextViewCoordinator, TextViewDelegate {
    
    /// 弱引用状态管理器
    private weak var state: LumiEditorState?
    private var editedRange: LSPRange?
    private var hoverTask: Task<Void, Never>?
    
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
    
    nonisolated func textViewDidChangeSelection(controller: TextViewController) {
        let state = self.state
        let cursor = controller.cursorPositions.first?.start
        hoverTask?.cancel()
        hoverTask = Task { @MainActor [weak state] in
            guard let state else { return }

            guard let cursor else {
                state.hoverText = nil
                return
            }

            // 轻量防抖，避免快速移动光标时频繁请求 LSP
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }

            let line = max(cursor.line - 1, 0)
            let character = max(cursor.column - 1, 0)
            state.hoverText = await state.lspCoordinator.requestHover(line: line, character: character)
        }
    }
    
    nonisolated func prepareCoordinator(controller: TextViewController) {}
    
    nonisolated func destroy() {
        hoverTask?.cancel()
        hoverTask = nil
        state = nil
    }
    
    func textView(_ textView: TextView, willReplaceContentsIn range: NSRange, with string: String) {
        editedRange = Self.lspRange(from: range, in: textView.string)
    }
    
    func textView(_ textView: TextView, didReplaceContentsIn range: NSRange, with string: String) {
        guard let lspRange = editedRange else { return }
        editedRange = nil
        let state = self.state
        DispatchQueue.main.async {
            state?.notifyLSPIncrementalChange(range: lspRange, text: string)
        }
    }
    
    private static func lspRange(from nsRange: NSRange, in text: String) -> LSPRange? {
        let utf16Count = text.utf16.count
        let startOffset = nsRange.location
        let endOffset = nsRange.location + nsRange.length
        
        guard startOffset >= 0, endOffset >= startOffset, endOffset <= utf16Count else {
            return nil
        }
        
        guard let start = lspPosition(utf16Offset: startOffset, in: text),
              let end = lspPosition(utf16Offset: endOffset, in: text) else {
            return nil
        }
        
        return LSPRange(start: start, end: end)
    }
    
    private static func lspPosition(utf16Offset: Int, in text: String) -> Position? {
        guard utf16Offset >= 0, utf16Offset <= text.utf16.count else { return nil }
        
        var line = 0
        var character = 0
        var consumed = 0
        
        for unit in text.utf16 {
            if consumed >= utf16Offset {
                break
            }
            if unit == 0x0A {
                line += 1
                character = 0
            } else {
                character += 1
            }
            consumed += 1
        }
        
        return Position(line: line, character: character)
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
    private var currentTargets: [LumiContextMenuTarget] = []
    private let injectedItemTag = 991
    private let injectedSeparatorTag = 992

    init(textView: TextView, state: LumiEditorState) {
        self.textView = textView
        self.state = state
    }

    /// 在右键菜单中注入自定义项
    func injectCustomItems(into menu: NSMenu) {
        // 先清除之前注入的项（防止重复）
        menu.items
            .enumerated()
            .reversed()
            .forEach { index, item in
                if item.tag == injectedItemTag || (item.isSeparatorItem && item.tag == injectedSeparatorTag) {
                    menu.removeItem(at: index)
                }
            }

        guard let textView, let state else { return }

        let hasSelection = textView.selectionManager.textSelections.contains { !$0.range.isEmpty }
        currentTargets.removeAll()

        // 插入分隔符到顶部
        let topSeparator = NSMenuItem.separator()
        topSeparator.tag = injectedSeparatorTag
        menu.insertItem(topSeparator, at: 0)

        // LSP / Chat actions
        let renameItem = buildInjectedItem(
            title: String(localized: "Rename Symbol", table: "LumiEditor"),
            image: "pencil.and.list.clipboard"
        ) {
            state.promptRenameSymbol()
        }
        menu.insertItem(renameItem, at: 0)

        let goToDefinitionItem = buildInjectedItem(
            title: String(localized: "Go to Definition", table: "LumiEditor"),
            image: "arrow.right.square"
        ) {
            Self.performGoToDefinition(textView: textView, state: state)
        }
        menu.insertItem(goToDefinitionItem, at: 0)

        let referencesItem = buildInjectedItem(
            title: String(localized: "Find References", table: "LumiEditor"),
            image: "link"
        ) {
            Task { @MainActor in
                await state.showReferencesFromCurrentCursor()
            }
        }
        menu.insertItem(referencesItem, at: 0)

        let formatItem = buildInjectedItem(
            title: String(localized: "Format Document", table: "LumiEditor"),
            image: "text.alignleft"
        ) {
            Task { @MainActor in
                await state.formatDocumentWithLSP()
            }
        }
        menu.insertItem(formatItem, at: 0)

        let middleSeparator = NSMenuItem.separator()
        middleSeparator.tag = injectedSeparatorTag
        menu.insertItem(middleSeparator, at: 0)

        let addLocationItem = buildInjectedItem(
            title: String(localized: "Add Location to Chat", table: "LumiEditor"),
            image: "mappin.and.ellipse"
        ) {
            Self.performAddLocationToChat(textView: textView, state: state)
        }
        menu.insertItem(addLocationItem, at: 0)

        if hasSelection {
            let addSelectionItem = buildInjectedItem(
                title: String(localized: "Add Selection to Chat", table: "LumiEditor"),
                image: "bubble.left.and.text.bubble.right"
            ) {
                Self.performAddSelectionToChat(textView: textView, state: state)
            }
            menu.insertItem(addSelectionItem, at: 0)
        }
    }

    private func buildInjectedItem(
        title: String,
        image: String,
        action: @escaping () -> Void
    ) -> NSMenuItem {
        let target = LumiContextMenuTarget(action: action)
        currentTargets.append(target)

        let item = NSMenuItem(
            title: title,
            action: #selector(LumiContextMenuTarget.addToChatClicked),
            keyEquivalent: ""
        )
        item.target = target
        item.tag = injectedItemTag
        item.image = NSImage(systemSymbolName: image, accessibilityDescription: nil)
        return item
    }

    // MARK: - Add to Chat Action

    private static func performAddSelectionToChat(textView: TextView, state: LumiEditorState) {
        let selections = textView.selectionManager.textSelections
        guard let firstSelection = selections.first, !firstSelection.range.isEmpty else { return }
        let fullText = textView.string as NSString
        let range = firstSelection.range
        guard range.location != NSNotFound, NSMaxRange(range) <= fullText.length else { return }
        let selectedText = fullText.substring(with: range)
        guard !selectedText.isEmpty else { return }
        let locationText = selectionLocationText(range: range, fullText: fullText, state: state)
        let languageHint = state.fileExtension

        let payload = """
        \(locationText)
        ```\(languageHint)
        \(selectedText)
        ```
        """
        NotificationCenter.postAddToChat(text: payload)
    }

    private static func performAddLocationToChat(textView: TextView, state: LumiEditorState) {
        let selection = textView.selectionManager.textSelections.first?.range ?? NSRange(location: 0, length: 0)
        let fullText = textView.string as NSString
        guard selection.location != NSNotFound else { return }
        let safeSelection = NSRange(
            location: min(max(selection.location, 0), fullText.length),
            length: min(max(selection.length, 0), max(0, fullText.length - min(max(selection.location, 0), fullText.length)))
        )
        let locationText = selectionLocationText(range: safeSelection, fullText: fullText, state: state)
        NotificationCenter.postAddToChat(text: locationText)
    }

    private static func performGoToDefinition(textView: TextView, state: LumiEditorState) {
        let selection = textView.selectionManager.textSelections.first?.range ?? NSRange(location: 0, length: 0)
        guard selection.location != NSNotFound else { return }

        let content = textView.string
        guard let pos = lspPosition(utf16Offset: selection.location, in: content) else { return }

        state.showStatusToast(
            String(localized: "Finding definition...", table: "LumiEditor"),
            level: .info,
            duration: 1.2
        )

        Task { @MainActor in
            guard let location = await state.lspCoordinator.requestDefinition(
                line: Int(pos.line),
                character: Int(pos.character)
            ) else {
                state.showStatusToast(
                    String(localized: "No definition found", table: "LumiEditor"),
                    level: .warning
                )
                return
            }

            guard let url = URL(string: location.uri) else {
                state.showStatusToast(
                    String(localized: "Definition URL is invalid", table: "LumiEditor"),
                    level: .error
                )
                return
            }
            let target = CursorPosition(
                start: CursorPosition.Position(
                    line: Int(location.range.start.line) + 1,
                    column: Int(location.range.start.character) + 1
                ),
                end: CursorPosition.Position(
                    line: Int(location.range.end.line) + 1,
                    column: Int(location.range.end.character) + 1
                )
            )
            state.openDefinitionLocation(url: url, target: target)
            state.showStatusToast(
                String(localized: "Jumped to definition", table: "LumiEditor"),
                level: .success
            )
        }
    }

    private static func selectionLocationText(range: NSRange, fullText: NSString, state: LumiEditorState) -> String {
        let startOffset = max(0, min(range.location, fullText.length))
        let endOffset = max(startOffset, min(NSMaxRange(range), fullText.length))

        let textBeforeStart = fullText.substring(with: NSRange(location: 0, length: startOffset))
        let textBeforeEnd = fullText.substring(with: NSRange(location: 0, length: endOffset))

        let startLine = textBeforeStart.filter { $0 == "\n" }.count + 1
        let startColumn = computeColumn(in: textBeforeStart)
        let endLine = textBeforeEnd.filter { $0 == "\n" }.count + 1
        let endColumn = computeColumn(in: textBeforeEnd)
        let filePath = state.relativeFilePath

        if startLine == endLine && startColumn == endColumn {
            return "\(filePath):\(startLine):\(startColumn)"
        }
        return "\(filePath):\(startLine):\(startColumn)-\(endLine):\(endColumn)"
    }

    private static func computeColumn(in text: String) -> Int {
        if let lastNL = text.lastIndex(of: "\n") {
            return text.distance(from: text.index(after: lastNL), to: text.endIndex) + 1
        }
        return text.count + 1
    }

    private static func lspPosition(utf16Offset: Int, in text: String) -> Position? {
        guard utf16Offset >= 0, utf16Offset <= text.utf16.count else { return nil }

        var line = 0
        var character = 0
        var consumed = 0

        for unit in text.utf16 {
            if consumed >= utf16Offset {
                break
            }
            if unit == 0x0A {
                line += 1
                character = 0
            } else {
                character += 1
            }
            consumed += 1
        }

        return Position(line: line, character: character)
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
