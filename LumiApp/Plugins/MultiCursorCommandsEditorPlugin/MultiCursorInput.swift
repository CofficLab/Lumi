import AppKit
import CodeEditTextView

// MARK: - Native Input Adapter
//
// 当前文件仍通过 swizzle 拦截 CodeEditTextView 的原生输入回调，
// 但业务决策已下沉到 EditorState / command system：
// - 多光标快捷键走统一 command id
// - insert/delete/newline/tab/backtab 的输入规则走 EditorState 入口
//
// 因此这里的职责仅剩：
// 1. 拦截原生输入事件
// 2. 把上下文（textView selections / replacementRange）转发给状态层
// 3. 将结果选区回写到 TextView

@MainActor
final class MultiCursorInputInstaller: NSObject {

    static let shared = MultiCursorInputInstaller()

    private static let swizzledKey = malloc(1)!
    private static let helperKey = malloc(1)!

    private override init() {}

    func register(textView: TextView, state: EditorState) {
        let targetClass = object_getClass(textView)!

        if objc_getAssociatedObject(targetClass, Self.swizzledKey) == nil {
            objc_setAssociatedObject(targetClass, Self.swizzledKey, true, .OBJC_ASSOCIATION_RETAIN)
            swizzleInsertText(for: targetClass)
            swizzleInsertNewline(for: targetClass)
            swizzleInsertTab(for: targetClass)
            swizzleInsertBacktab(for: targetClass)
            swizzleDeleteBackward(for: targetClass)
            swizzlePerformKeyEquivalent(for: targetClass)
            swizzleMoveLeft(for: targetClass)
            swizzleMoveRight(for: targetClass)
            swizzleCancelOperation(for: targetClass)
        }

        if objc_getAssociatedObject(textView, Self.helperKey) == nil {
            let helper = MultiCursorInputHelper(textView: textView, state: state)
            objc_setAssociatedObject(textView, Self.helperKey, helper, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    static func helper(for textView: TextView) -> MultiCursorInputHelper? {
        objc_getAssociatedObject(textView, helperKey) as? MultiCursorInputHelper
    }

    private func swizzleInsertText(for targetClass: AnyClass) {
        let selector = #selector(NSTextView.insertText(_:replacementRange:))
        guard let method = class_getInstanceMethod(targetClass, selector) else { return }
        let originalIMP = method_getImplementation(method)

        let block: @convention(block) (TextView, Any, NSRange) -> Void = { textView, string, replacementRange in
            if let helper = Self.helper(for: textView), helper.handleInsertText(string, replacementRange: replacementRange) {
                return
            }

            typealias Original = @convention(c) (AnyObject, Selector, Any, NSRange) -> Void
            unsafeBitCast(originalIMP, to: Original.self)(textView, selector, string, replacementRange)
        }

        class_replaceMethod(targetClass, selector, imp_implementationWithBlock(block), method_getTypeEncoding(method))
    }

    private func swizzleDeleteBackward(for targetClass: AnyClass) {
        let selector = #selector(NSResponder.deleteBackward(_:))
        guard let method = class_getInstanceMethod(targetClass, selector) else { return }
        let originalIMP = method_getImplementation(method)

        let block: @convention(block) (TextView, Any?) -> Void = { textView, sender in
            if let helper = Self.helper(for: textView), helper.handleDeleteBackward() {
                return
            }

            typealias Original = @convention(c) (AnyObject, Selector, Any?) -> Void
            unsafeBitCast(originalIMP, to: Original.self)(textView, selector, sender)
        }

        class_replaceMethod(targetClass, selector, imp_implementationWithBlock(block), method_getTypeEncoding(method))
    }

    private func swizzleInsertNewline(for targetClass: AnyClass) {
        let selector = #selector(NSResponder.insertNewline(_:))
        guard let method = class_getInstanceMethod(targetClass, selector) else { return }
        let originalIMP = method_getImplementation(method)

        let block: @convention(block) (TextView, Any?) -> Void = { textView, sender in
            if let helper = Self.helper(for: textView), helper.handleInsertNewline() {
                return
            }

            typealias Original = @convention(c) (AnyObject, Selector, Any?) -> Void
            unsafeBitCast(originalIMP, to: Original.self)(textView, selector, sender)
        }

        class_replaceMethod(targetClass, selector, imp_implementationWithBlock(block), method_getTypeEncoding(method))
    }

    private func swizzleInsertTab(for targetClass: AnyClass) {
        let selector = #selector(NSResponder.insertTab(_:))
        guard let method = class_getInstanceMethod(targetClass, selector) else { return }
        let originalIMP = method_getImplementation(method)

        let block: @convention(block) (TextView, Any?) -> Void = { textView, sender in
            if let helper = Self.helper(for: textView), helper.handleInsertTab() {
                return
            }

            typealias Original = @convention(c) (AnyObject, Selector, Any?) -> Void
            unsafeBitCast(originalIMP, to: Original.self)(textView, selector, sender)
        }

        class_replaceMethod(targetClass, selector, imp_implementationWithBlock(block), method_getTypeEncoding(method))
    }

    private func swizzleInsertBacktab(for targetClass: AnyClass) {
        let selector = #selector(NSResponder.insertBacktab(_:))
        guard let method = class_getInstanceMethod(targetClass, selector) else { return }
        let originalIMP = method_getImplementation(method)

        let block: @convention(block) (TextView, Any?) -> Void = { textView, sender in
            if let helper = Self.helper(for: textView), helper.handleInsertBacktab() {
                return
            }

            typealias Original = @convention(c) (AnyObject, Selector, Any?) -> Void
            unsafeBitCast(originalIMP, to: Original.self)(textView, selector, sender)
        }

        class_replaceMethod(targetClass, selector, imp_implementationWithBlock(block), method_getTypeEncoding(method))
    }

    private func swizzlePerformKeyEquivalent(for targetClass: AnyClass) {
        let selector = #selector(NSView.performKeyEquivalent(with:))
        guard let method = class_getInstanceMethod(targetClass, selector) else { return }
        let originalIMP = method_getImplementation(method)

        let block: @convention(block) (TextView, NSEvent) -> Bool = { textView, event in
            if let helper = Self.helper(for: textView), helper.handlePerformKeyEquivalent(event) {
                return true
            }

            typealias Original = @convention(c) (AnyObject, Selector, NSEvent) -> Bool
            return unsafeBitCast(originalIMP, to: Original.self)(textView, selector, event)
        }

        class_replaceMethod(targetClass, selector, imp_implementationWithBlock(block), method_getTypeEncoding(method))
    }

    private func swizzleMoveLeft(for targetClass: AnyClass) {
        let selector = #selector(NSResponder.moveLeft(_:))
        guard let method = class_getInstanceMethod(targetClass, selector) else { return }
        let originalIMP = method_getImplementation(method)

        let block: @convention(block) (TextView, Any?) -> Void = { textView, sender in
            if let helper = Self.helper(for: textView), helper.handleMoveLeft() {
                return
            }

            typealias Original = @convention(c) (AnyObject, Selector, Any?) -> Void
            unsafeBitCast(originalIMP, to: Original.self)(textView, selector, sender)
        }

        class_replaceMethod(targetClass, selector, imp_implementationWithBlock(block), method_getTypeEncoding(method))
    }

    private func swizzleMoveRight(for targetClass: AnyClass) {
        let selector = #selector(NSResponder.moveRight(_:))
        guard let method = class_getInstanceMethod(targetClass, selector) else { return }
        let originalIMP = method_getImplementation(method)

        let block: @convention(block) (TextView, Any?) -> Void = { textView, sender in
            if let helper = Self.helper(for: textView), helper.handleMoveRight() {
                return
            }

            typealias Original = @convention(c) (AnyObject, Selector, Any?) -> Void
            unsafeBitCast(originalIMP, to: Original.self)(textView, selector, sender)
        }

        class_replaceMethod(targetClass, selector, imp_implementationWithBlock(block), method_getTypeEncoding(method))
    }

    private func swizzleCancelOperation(for targetClass: AnyClass) {
        let selector = #selector(NSResponder.cancelOperation(_:))
        guard let method = class_getInstanceMethod(targetClass, selector) else { return }
        let originalIMP = method_getImplementation(method)

        let block: @convention(block) (TextView, Any?) -> Void = { textView, sender in
            if let helper = Self.helper(for: textView), helper.handleCancelOperation() {
                return
            }

            typealias Original = @convention(c) (AnyObject, Selector, Any?) -> Void
            unsafeBitCast(originalIMP, to: Original.self)(textView, selector, sender)
        }

        class_replaceMethod(targetClass, selector, imp_implementationWithBlock(block), method_getTypeEncoding(method))
    }
}

@MainActor
final class MultiCursorInputHelper: NSObject {

    private weak var textView: TextView?
    private weak var state: EditorState?
    private var isApplyingMultiCursorEdit = false

    init(textView: TextView, state: EditorState) {
        self.textView = textView
        self.state = state
    }

    func handleInsertText(_ string: Any, replacementRange: NSRange) -> Bool {
        guard let textView, let state else { return false }
        guard !isApplyingMultiCursorEdit else { return false }

        let text: String
        if let s = string as? String {
            text = s
        } else if let attr = string as? NSAttributedString {
            text = attr.string
        } else {
            return false
        }

        isApplyingMultiCursorEdit = true
        defer { isApplyingMultiCursorEdit = false }

        state.logMultiCursorInput(
            action: "insertText.before",
            textViewSelections: textView.selectionManager.textSelections.map(\.range),
            note: "replacementRange=\(NSStringFromRange(replacementRange)) textLength=\((text as NSString).length)"
        )
        guard state.handleTextInput(
            text,
            replacementRange: replacementRange,
            textViewSelections: textView.selectionManager.textSelections.map(\.range)
        ) else {
            return false
        }
        textView.selectionManager.setSelectedRanges(state.currentSelectionsAsNSRanges())
        state.logMultiCursorInput(
            action: "insertText.after",
            textViewSelections: textView.selectionManager.textSelections.map(\.range),
            note: "resultSelectionCount=\(state.currentSelectionsAsNSRanges().count)"
        )
        return true
    }

    func handleDeleteBackward() -> Bool {
        guard let textView, let state else { return false }
        guard !isApplyingMultiCursorEdit else { return false }

        isApplyingMultiCursorEdit = true
        defer { isApplyingMultiCursorEdit = false }

        state.logMultiCursorInput(
            action: "deleteBackward.before",
            textViewSelections: textView.selectionManager.textSelections.map(\.range)
        )
        guard state.handleDeleteBackwardInput() else {
            return false
        }
        textView.selectionManager.setSelectedRanges(state.currentSelectionsAsNSRanges())
        state.logMultiCursorInput(
            action: "deleteBackward.after",
            textViewSelections: textView.selectionManager.textSelections.map(\.range),
            note: "resultSelectionCount=\(state.currentSelectionsAsNSRanges().count)"
        )
        return true
    }

    func handleInsertNewline() -> Bool {
        guard let textView, let state else { return false }
        guard !isApplyingMultiCursorEdit else { return false }

        isApplyingMultiCursorEdit = true
        defer { isApplyingMultiCursorEdit = false }

        guard state.handleInsertNewlineInput(
            textViewSelections: textView.selectionManager.textSelections.map(\.range)
        ) else {
            return false
        }

        textView.selectionManager.setSelectedRanges(state.currentSelectionsAsNSRanges())
        return true
    }

    func handleInsertTab() -> Bool {
        guard let textView, let state else { return false }
        guard !isApplyingMultiCursorEdit else { return false }

        isApplyingMultiCursorEdit = true
        defer { isApplyingMultiCursorEdit = false }

        guard state.handleInsertTabInput(
            textViewSelections: textView.selectionManager.textSelections.map(\.range)
        ) else {
            return false
        }

        textView.selectionManager.setSelectedRanges(state.currentSelectionsAsNSRanges())
        return true
    }

    func handleInsertBacktab() -> Bool {
        guard let textView, let state else { return false }
        guard !isApplyingMultiCursorEdit else { return false }

        isApplyingMultiCursorEdit = true
        defer { isApplyingMultiCursorEdit = false }

        guard state.handleInsertBacktabInput(
            textViewSelections: textView.selectionManager.textSelections.map(\.range)
        ) else {
            return false
        }

        textView.selectionManager.setSelectedRanges(state.currentSelectionsAsNSRanges())
        return true
    }

    func handlePerformKeyEquivalent(_ event: NSEvent) -> Bool {
        guard let textView, let state else { return false }
        guard event.type == .keyDown else { return false }

        let commandPressed = event.modifierFlags.contains(.command)
        let shiftPressed = event.modifierFlags.contains(.shift)
        let key = event.charactersIgnoringModifiers?.lowercased()

        if commandPressed, !shiftPressed, key == "d" {
            state.logMultiCursorInput(
                action: "cmd+d.before",
                textViewSelections: textView.selectionManager.textSelections.map(\.range),
                note: "command=builtin.add-next-occurrence"
            )
            state.performEditorCommand(id: "builtin.add-next-occurrence")
            textView.selectionManager.setSelectedRanges(state.currentSelectionsAsNSRanges())
            state.logMultiCursorInput(
                action: "cmd+d.after",
                textViewSelections: textView.selectionManager.textSelections.map(\.range),
                note: "appliedRangeCount=\(state.currentSelectionsAsNSRanges().count)"
            )
            return true
        }

        if commandPressed, !shiftPressed, key == "u" {
            state.logMultiCursorInput(
                action: "cmd+u.before",
                textViewSelections: textView.selectionManager.textSelections.map(\.range),
                note: "command=builtin.remove-last-occurrence-selection"
            )
            state.performEditorCommand(id: "builtin.remove-last-occurrence-selection")
            textView.selectionManager.setSelectedRanges(state.currentSelectionsAsNSRanges())
            state.logMultiCursorInput(
                action: "cmd+u.after",
                textViewSelections: textView.selectionManager.textSelections.map(\.range),
                note: "appliedRangeCount=\(state.currentSelectionsAsNSRanges().count)"
            )
            return true
        }

        if commandPressed, shiftPressed, key == "l" {
            state.logMultiCursorInput(
                action: "cmd+shift+l.before",
                textViewSelections: textView.selectionManager.textSelections.map(\.range),
                note: "command=builtin.select-all-occurrences"
            )
            state.performEditorCommand(id: "builtin.select-all-occurrences")
            textView.selectionManager.setSelectedRanges(state.currentSelectionsAsNSRanges())
            state.logMultiCursorInput(
                action: "cmd+shift+l.after",
                textViewSelections: textView.selectionManager.textSelections.map(\.range),
                note: "appliedRangeCount=\(state.currentSelectionsAsNSRanges().count)"
            )
            return true
        }

        return false
    }

    func handleMoveLeft() -> Bool {
        handleMove(selectorName: "moveLeft")
    }

    func handleMoveRight() -> Bool {
        handleMove(selectorName: "moveRight")
    }

    func handleCancelOperation() -> Bool {
        guard let textView, let state else { return false }
        if state.cancelActiveSnippetSession() {
            textView.selectionManager.setSelectedRanges(state.currentSelectionsAsNSRanges())
            return true
        }
        guard state.multiCursorState.isEnabled else { return false }

        state.logMultiCursorInput(
            action: "cancel.before",
            textViewSelections: textView.selectionManager.textSelections.map(\.range),
            note: "command=builtin.clear-additional-cursors"
        )
        state.performEditorCommand(id: "builtin.clear-additional-cursors")
        textView.selectionManager.setSelectedRanges(state.currentSelectionsAsNSRanges())
        state.logMultiCursorInput(
            action: "cancel.after",
            textViewSelections: textView.selectionManager.textSelections.map(\.range)
        )
        return true
    }

    private func handleMove(selectorName: String) -> Bool {
        guard let textView, let state else { return false }
        guard state.multiCursorState.all.count > 1 else { return false }
        guard !isApplyingMultiCursorEdit else { return false }

        state.logMultiCursorInput(
            action: "\(selectorName).before",
            textViewSelections: textView.selectionManager.textSelections.map(\.range),
            note: "visibleTextSelections=\(textView.selectionManager.textSelections.count)"
        )

        DispatchQueue.main.async {
            textView.needsLayout = true
            textView.layoutSubtreeIfNeeded()
            state.logMultiCursorInput(
                action: "\(selectorName).afterAsyncRefresh",
                textViewSelections: textView.selectionManager.textSelections.map(\.range),
                note: "forcedLayoutRefresh=true"
            )
        }

        return false
    }
}
