import Foundation
import AppKit
import CodeEditSourceEditor
import CodeEditTextView
import SwiftUI
import LanguageServerProtocol
import os

/// 文本变更协调器
/// 监听 CodeEditSourceEditor 的文本与焦点事件，通知 EditorState 更新脏状态并在失焦时保存
final class EditorCoordinator: TextViewCoordinator, TextViewDelegate {
    
    /// 弱引用状态管理器
    private weak var state: EditorState?
    private var editedRange: LSPRange?
    private weak var textViewController: TextViewController?
    private var endEditingObserver: NSObjectProtocol?
    /// 跳转定义代理（由外部注入）
    weak var jumpDelegate: EditorJumpToDefinitionDelegate?
    
    init(state: EditorState) {
        self.state = state
    }
    
    // MARK: - TextViewCoordinator
    
    nonisolated func prepareCoordinator(controller: TextViewController) {
        if let endEditingObserver {
            NotificationCenter.default.removeObserver(endEditingObserver)
            self.endEditingObserver = nil
        }
        textViewController = controller
        jumpDelegate?.textViewController = controller
        let st = state
        DispatchQueue.main.async {
            st?.focusedTextView = controller.textView
        }

        endEditingObserver = NotificationCenter.default.addObserver(
            forName: NSText.didEndEditingNotification,
            object: controller.textView,
            queue: .main
        ) { [weak st] _ in
            st?.saveNowIfNeeded(reason: "editor_focus_lost")
        }
    }
    
    nonisolated func textViewDidChangeText(controller: TextViewController) {
        let state = self.state
        if EditorPlugin.verbose {
            EditorPlugin.logger.info("\(EditorState.t)文本变更: state=\(state != nil), 长度=\(controller.textView?.string.count ?? -1)")
        }
        // 延迟到下一个 RunLoop，避免 "Modifying state during view update"
        DispatchQueue.main.async {
            if state == nil {
                EditorPlugin.logger.warning("\(EditorState.t)Coordinator 已被释放，state 为 nil")
            }
            state?.notifyContentChanged()
            guard let state else { return }
            Task { @MainActor in
                let context = Self.interactionContext(
                    controller: controller,
                    state: state,
                    typedCharacter: Self.lastTypedCharacter(in: controller)
                )
                await state.editorExtensions.runInteractionTextDidChange(
                    context: context,
                    state: state,
                    controller: controller
                )
            }
        }
    }
    
    nonisolated func textViewDidChangeSelection(controller: TextViewController) {
        let state = self.state
        let selectionRanges = controller.textView?.selectionManager.textSelections.map(\.range) ?? []
        let cursorPositions = controller.cursorPositions
        Task { @MainActor [weak state] in
            guard let state else { return }
            state.logMultiCursorInput(
                action: "coordinator.selectionDidChange",
                textViewSelections: selectionRanges,
                note: "cursorPositions=\(cursorPositions.count)"
            )

            // 多光标模式下，跳过 syncSelections 和 clearUnfocusedMultiCursorsIfNeeded。
            // 原因：CodeEditSourceEditor 的 updateCursorPosition() 会把 textSelections 转换为
            // cursorPositions（基于 line/column），如果 layoutManager 尚未布局某些 offset，
            // textLineForOffset 会返回 nil 导致部分选区丢失。然后 Coordinator 通过 Binding
            // 回写 cursorPositions → SwiftUI 触发 updateNSViewController → setCursorPositions
            // 把减少后的选区覆盖回 selectionManager，导致光标丢失。
            let cursorCount = controller.textView?.selectionManager.textSelections.count ?? 0
            let stateCount = state.multiCursorState.all.count
            let isMultiCursorSession = stateCount > 1 || cursorCount > 1

            if !isMultiCursorSession {
                Self.syncSelections(from: controller, to: state)
                state.clearUnfocusedMultiCursorsIfNeeded()
            }

            let cursor = controller.cursorPositions.first

            state.updateSelectedProblemDiagnostic(for: cursor)

            guard let cursor else {
                return
            }

            // Hover 请求已由 HoverEditorCoordinator 统一处理，此处不再重复请求

            let lspLine = max(cursor.start.line - 1, 0)
            let lspCharacter = max(cursor.start.column - 1, 0)

            // ✅ Code Action 请求放入独立 Task，不阻塞后续光标/插件操作
            if let fileURL = state.currentFileURL {
                let diagnostics = state.problemDiagnostics.filter { diag in
                    Int(diag.range.start.line) + 1 == cursor.start.line ||
                    (Int(diag.range.start.line) + 1 < cursor.start.line && Int(diag.range.end.line) + 1 >= cursor.start.line)
                }
                let caURI = fileURL.absoluteString
                let caDiags = diagnostics
                let caLine = lspLine
                let caChar = lspCharacter
                let caLangId = state.detectedLanguage?.tsName ?? "swift"
                let caSelectedText: String? = {
                    guard let textView = controller.textView,
                          let selection = textView.selectionManager.textSelections.first else { return nil }
                    let range = selection.range
                    guard range.location != NSNotFound, range.length > 0,
                          let swiftRange = Range(range, in: textView.string) else { return nil }
                    return String(textView.string[swiftRange])
                }()
                Task { @MainActor in
                    await state.codeActionProvider.requestCodeActionsForLine(
                        uri: caURI,
                        line: caLine,
                        character: caChar,
                        diagnostics: caDiags,
                        languageId: caLangId,
                        selectedText: caSelectedText
                    )
                }
            }

            let context = Self.interactionContext(
                controller: controller,
                state: state,
                typedCharacter: nil
            )
            await state.editorExtensions.runInteractionSelectionDidChange(
                context: context,
                state: state,
                controller: controller
            )
        }
    }
    
    nonisolated func destroy() {
        if EditorPlugin.verbose {
            EditorPlugin.logger.info("\(EditorState.t)Coordinator 销毁: state=\(self.state != nil)")
        }
        if let endEditingObserver {
            NotificationCenter.default.removeObserver(endEditingObserver)
            self.endEditingObserver = nil
        }
        let st = state
        state = nil
        textViewController = nil
        DispatchQueue.main.async {
            st?.focusedTextView = nil
        }
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
            // 关键：CodeEditSourceEditor 对实现了 TextViewDelegate 的 coordinator
            // 只调用 textView(_:didReplaceContentsIn:with:)，不会调用 textViewDidChangeText(controller:)。
            // 因此脏状态更新逻辑必须在这里触发。
            state?.notifyContentChanged()
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

    @MainActor
    private static func syncSelections(
        from controller: TextViewController,
        to state: EditorState
    ) {
        guard let textView = controller.textView else { return }

        // Phase 2: 通过 EditorSelectionMapper 进行 view → canonical 转换
        let currentCanonical = state.canonicalSelectionSet

        guard let viewSelectionSet = EditorSelectionMapper.toCanonical(
            from: textView,
            currentState: currentCanonical
        ) else { return }

        // 多光标保护：原生回传选区数量减少时，拒绝覆盖内核（可能是 CodeEdit 内部丢失）
        guard EditorSelectionMapper.shouldAcceptCanonicalUpdate(
            viewSelections: viewSelectionSet,
            currentState: currentCanonical
        ) else { return }

        state.applyCanonicalSelectionSet(viewSelectionSet)
    }

    @MainActor
    private static func interactionContext(
        controller: TextViewController,
        state: EditorState,
        typedCharacter: String?
    ) -> EditorInteractionContext {
        let textView = controller.textView
        let text = textView?.string ?? ""
        let selection = textView?.selectionManager.textSelections.first?.range ?? NSRange(location: 0, length: 0)
        let offset = max(selection.location, 0)
        let position = lspPosition(utf16Offset: offset, in: text)
            ?? Position(line: max(state.cursorLine - 1, 0), character: max(state.cursorColumn - 1, 0))

        return EditorInteractionContext(
            languageId: state.detectedLanguage?.tsName ?? "swift",
            line: Int(position.line),
            character: Int(position.character),
            typedCharacter: typedCharacter
        )
    }

    @MainActor
    private static func lastTypedCharacter(in controller: TextViewController) -> String? {
        guard let textView = controller.textView else { return nil }
        let text = textView.string as NSString
        guard let selection = textView.selectionManager.textSelections.first else { return nil }
        let location = selection.range.location
        guard location != NSNotFound, location > 0, location <= text.length else { return nil }
        return text.substring(with: NSRange(location: location - 1, length: 1))
    }
}

/// 光标位置协调器
/// 监听光标位置变化，更新行号/列号信息
final class CursorCoordinator: TextViewCoordinator {
    
    private weak var state: EditorState?
    
    init(state: EditorState) {
        self.state = state
    }
    
    // MARK: - TextViewCoordinator
    
    nonisolated func textViewDidChangeSelection(controller: TextViewController) {
        let state = self.state
        let positions = controller.cursorPositions
        
        // 延迟到下一个 RunLoop，避免 "Modifying state during view update"
        DispatchQueue.main.async {
            if let first = positions.first {
                state?.applyPrimaryCursorObservation(
                    line: first.start.line,
                    column: first.start.column
                )
            } else {
                state?.applyCursorObservation(positions)
            }
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
final class ContextMenuCoordinator: TextViewCoordinator {

    private weak var state: EditorState?

    init(state: EditorState) {
        self.state = state
    }

    nonisolated func prepareCoordinator(controller: TextViewController) {}

    nonisolated func controllerDidAppear(controller: TextViewController) {
        guard let textView = controller.textView else { return }
        let state = self.state

        Task { @MainActor [weak state] in
            guard let state else { return }
            MultiCursorInputInstaller.shared.register(textView: textView, state: state)
            ContextMenuManager.shared.register(textView: textView, state: state)
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
final class ContextMenuManager {

    static let shared = ContextMenuManager()

    /// 关联对象 key：标记是否已经 swizzle 过该类
    private static let swizzledKey = malloc(1)!

    /// 关联对象 key：存储每个 textView 实例对应的 helper
    private static let helperKey = malloc(1)!

    private init() {}

    /// 注册 textView，执行 swizzle（仅首次）并绑定 helper
    func register(textView: TextView, state: EditorState) {
        let targetClass = object_getClass(textView)!

        // 确保这个类只 swizzle 一次
        if objc_getAssociatedObject(targetClass, Self.swizzledKey) == nil {
            objc_setAssociatedObject(targetClass, Self.swizzledKey, true, .OBJC_ASSOCIATION_RETAIN)
            swizzleMenuForClass(targetClass)
        }

        // 为每个 textView 实例绑定 helper
        if objc_getAssociatedObject(textView, Self.helperKey) == nil {
            let helper = ContextMenuHelper(textView: textView, state: state)
            objc_setAssociatedObject(textView, Self.helperKey, helper, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    /// 获取某个 textView 实例关联的 helper
    static func helperForTextView(_ textView: TextView) -> ContextMenuHelper? {
        objc_getAssociatedObject(textView, helperKey) as? ContextMenuHelper
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
            if let helper = ContextMenuManager.helperForTextView(textView) {
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
final class ContextMenuHelper: NSObject {

    private weak var textView: TextView?
    private weak var state: EditorState?
    private var currentTargets: [ContextMenuTarget] = []
    private let injectedItemTag = 991
    private let injectedSeparatorTag = 992

    init(textView: TextView, state: EditorState) {
        self.textView = textView
        self.state = state
    }

    /// 在右键菜单中注入自定义项
    ///
    /// 所有功能菜单项均由编辑器子插件通过 `EditorCommandContributor` 注册，
    /// 此处仅负责从注册中心聚合命令并注入到右键菜单中。
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

        currentTargets.removeAll()

        // 插入分隔符到顶部
        let topSeparator = NSMenuItem.separator()
        topSeparator.tag = injectedSeparatorTag
        menu.insertItem(topSeparator, at: 0)

        // 从插件注册中心获取所有命令（包括多光标、Chat 集成、LSP 命令等）
        let (line, character) = Self.cursorLSPLineCharacter(textView: textView, state: state)
        let hasSelection = textView.selectionManager.textSelections.contains { !$0.range.isEmpty }
        let commandContext = EditorCommandContext(
            languageId: state.detectedLanguage?.tsName ?? "swift",
            hasSelection: hasSelection,
            line: line,
            character: character
        )
        let pluginCommands = state.editorExtensions.commandSuggestions(
            for: commandContext,
            state: state,
            textView: textView
        )
        for command in pluginCommands.reversed() {
            let commandItem = buildInjectedItem(
                title: command.title,
                image: command.systemImage,
                action: command.action
            )
            commandItem.isEnabled = command.isEnabled
            menu.insertItem(commandItem, at: 0)
        }
    }

    private func buildInjectedItem(
        title: String,
        image: String,
        action: @escaping () -> Void
    ) -> NSMenuItem {
        let target = ContextMenuTarget(action: action)
        currentTargets.append(target)

        let item = NSMenuItem(
            title: title,
            action: #selector(ContextMenuTarget.addToChatClicked),
            keyEquivalent: ""
        )
        item.target = target
        item.tag = injectedItemTag
        item.image = NSImage(systemSymbolName: image, accessibilityDescription: nil)
        return item
    }

    private static func cursorLSPLineCharacter(textView: TextView, state: EditorState) -> (Int, Int) {
        let selection = textView.selectionManager.textSelections.first?.range ?? NSRange(location: 0, length: 0)
        let offset = max(selection.location, 0)
        guard let position = lspPosition(utf16Offset: offset, in: textView.string) else {
            return (max(state.cursorLine - 1, 0), max(state.cursorColumn - 1, 0))
        }
        return (Int(position.line), Int(position.character))
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

final class ContextMenuTarget: NSObject {
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    @objc func addToChatClicked() {
        action()
    }
}
