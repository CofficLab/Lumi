import AppKit
import CodeEditTextView

@MainActor
final class LumiMultiCursorInputInstaller: NSObject {

    static let shared = LumiMultiCursorInputInstaller()

    private static let swizzledKey = malloc(1)!
    private static let helperKey = malloc(1)!

    private override init() {}

    func register(textView: TextView, state: LumiEditorState) {
        let targetClass = object_getClass(textView)!

        if objc_getAssociatedObject(targetClass, Self.swizzledKey) == nil {
            objc_setAssociatedObject(targetClass, Self.swizzledKey, true, .OBJC_ASSOCIATION_RETAIN)
            swizzleInsertText(for: targetClass)
            swizzleDeleteBackward(for: targetClass)
            swizzlePerformKeyEquivalent(for: targetClass)
            swizzleCancelOperation(for: targetClass)
        }

        if objc_getAssociatedObject(textView, Self.helperKey) == nil {
            let helper = LumiMultiCursorInputHelper(textView: textView, state: state)
            objc_setAssociatedObject(textView, Self.helperKey, helper, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    static func helper(for textView: TextView) -> LumiMultiCursorInputHelper? {
        objc_getAssociatedObject(textView, helperKey) as? LumiMultiCursorInputHelper
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
final class LumiMultiCursorInputHelper: NSObject {

    private weak var textView: TextView?
    private weak var state: LumiEditorState?
    private var isApplyingMultiCursorEdit = false

    init(textView: TextView, state: LumiEditorState) {
        self.textView = textView
        self.state = state
    }

    func handleInsertText(_ string: Any, replacementRange: NSRange) -> Bool {
        guard let textView, let state else { return false }
        guard state.multiCursorState.all.count > 1 else { return false }
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

        let selections = state.multiCursorState.all
        let result = LumiMultiCursorEditEngine.apply(
            text: textView.string,
            selections: selections,
            operation: .replaceSelection(text)
        )

        textView.textStorage?.setAttributedString(NSAttributedString(string: result.text))
        state.content?.mutableString.setString(result.text)
        state.totalLines = result.text.filter { $0 == "\n" }.count + 1
        state.setSelections(result.selections)
        textView.selectionManager.setSelectedRanges(state.currentSelectionsAsNSRanges())
        state.lspCoordinator.replaceDocument(result.text)
        state.notifyContentChanged()
        return true
    }

    func handleDeleteBackward() -> Bool {
        guard let textView, let state else { return false }
        guard state.multiCursorState.all.count > 1 else { return false }
        guard !isApplyingMultiCursorEdit else { return false }

        isApplyingMultiCursorEdit = true
        defer { isApplyingMultiCursorEdit = false }

        let selections = state.multiCursorState.all
        let result = LumiMultiCursorEditEngine.apply(
            text: textView.string,
            selections: selections,
            operation: .deleteBackward
        )

        textView.textStorage?.setAttributedString(NSAttributedString(string: result.text))
        state.content?.mutableString.setString(result.text)
        state.totalLines = result.text.filter { $0 == "\n" }.count + 1
        state.setSelections(result.selections)
        textView.selectionManager.setSelectedRanges(state.currentSelectionsAsNSRanges())
        state.lspCoordinator.replaceDocument(result.text)
        state.notifyContentChanged()
        return true
    }

    func handlePerformKeyEquivalent(_ event: NSEvent) -> Bool {
        guard let textView, let state else { return false }
        guard event.type == .keyDown else { return false }

        let commandPressed = event.modifierFlags.contains(.command)
        let shiftPressed = event.modifierFlags.contains(.shift)
        let key = event.charactersIgnoringModifiers?.lowercased()

        if commandPressed, !shiftPressed, key == "d" {
            let currentSelection = textView.selectionManager.textSelections.last?.range ?? NSRange(location: NSNotFound, length: 0)
            // 同步选区到 state，确保 addNextOccurrence 使用最新的选区
            let mapped = textView.selectionManager.textSelections
                .map { $0.range }
                .filter { $0.location != NSNotFound }
                .map { LumiMultiCursorSelection(location: $0.location, length: $0.length) }
            if !mapped.isEmpty {
                state.setSelections(mapped)
            }
            if let ranges = state.addNextOccurrence(from: currentSelection) {
                textView.selectionManager.setSelectedRanges(ranges)
            }
            return true
        }

        if commandPressed, !shiftPressed, key == "u" {
            if let ranges = state.removeLastOccurrenceSelection() {
                textView.selectionManager.setSelectedRanges(ranges)
            }
            return true
        }

        if commandPressed, shiftPressed, key == "l" {
            let currentSelection = textView.selectionManager.textSelections.last?.range ?? NSRange(location: NSNotFound, length: 0)
            if let ranges = state.addAllOccurrences(from: currentSelection) {
                textView.selectionManager.setSelectedRanges(ranges)
            }
            return true
        }

        return false
    }

    func handleCancelOperation() -> Bool {
        guard let textView, let state else { return false }
        guard state.multiCursorState.isEnabled else { return false }

        state.clearMultiCursors()
        textView.selectionManager.setSelectedRanges(state.currentSelectionsAsNSRanges())
        return true
    }
}
