import Foundation
import AppKit
import CodeEditSourceEditor
import CodeEditTextView
import SwiftUI
import LanguageServerProtocol

/// 文本变更协调器
/// 监听 CodeEditSourceEditor 的文本变更，通知 EditorState 触发自动保存
final class EditorCoordinator: TextViewCoordinator, TextViewDelegate {
    
    /// 弱引用状态管理器
    private weak var state: EditorState?
    private var editedRange: LSPRange?
    private weak var textViewController: TextViewController?
    /// 跳转定义代理（由外部注入）
    weak var jumpDelegate: EditorJumpToDefinitionDelegate?
    
    init(state: EditorState) {
        self.state = state
    }
    
    // MARK: - TextViewCoordinator
    
    nonisolated func prepareCoordinator(controller: TextViewController) {
        textViewController = controller
        jumpDelegate?.textViewController = controller
        let st = state
        DispatchQueue.main.async {
            st?.focusedTextView = controller.textView
        }
        print("🔧 [AutoSave] EditorCoordinator.prepareCoordinator | state=\(state != nil)")
    }
    
    nonisolated func textViewDidChangeText(controller: TextViewController) {
        let state = self.state
        print("📝 [AutoSave] EditorCoordinator.textViewDidChangeText 触发 | state=\(state != nil) | textLen=\(controller.textView?.string.count ?? -1)")
        // 延迟到下一个 RunLoop，避免 "Modifying state during view update"
        DispatchQueue.main.async {
            if state == nil {
                print("⚠️ [AutoSave] EditorCoordinator.textViewDidChangeText: state is nil! Coordinator 已被释放")
            }
            state?.notifyContentChanged()
            state?.scheduleInlayHintsRefreshIfNeeded(controller: controller)
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

            let cursor = controller.cursorPositions.first?.start

            guard let cursor else {
                state.selectedProblemDiagnostic = nil
                return
            }

            state.selectedProblemDiagnostic = state.problemDiagnostics.first(where: { diag in
                let startLine = Int(diag.range.start.line) + 1
                let endLine = Int(diag.range.end.line) + 1
                let startColumn = Int(diag.range.start.character) + 1
                let endColumn = Int(diag.range.end.character) + 1

                if cursor.line < startLine || cursor.line > endLine {
                    return false
                }
                if startLine == endLine {
                    let upperBound = max(endColumn, startColumn)
                    return cursor.column >= startColumn && cursor.column <= upperBound
                }
                if cursor.line == startLine {
                    return cursor.column >= startColumn
                }
                if cursor.line == endLine {
                    return cursor.column <= max(endColumn, 1)
                }
                return true
            })

            // Hover 请求已由 HoverEditorCoordinator 统一处理，此处不再重复请求
            
            let lspLine = max(cursor.line - 1, 0)
            let lspCharacter = max(cursor.column - 1, 0)
            
            // 触发文档高亮（Symbol Highlight）
            if let fileURL = state.currentFileURL, let content = state.content {
                await state.documentHighlightProvider.requestHighlight(
                    uri: fileURL.absoluteString,
                    line: lspLine,
                    character: lspCharacter,
                    content: content.string
                )
            }
            
            // 触发代码动作（如果有诊断）
            if let fileURL = state.currentFileURL, let contentString = state.content?.string {
                let diagnostics = state.problemDiagnostics.filter { diag in
                    Int(diag.range.start.line) + 1 == cursor.line ||
                    (Int(diag.range.start.line) + 1 < cursor.line && Int(diag.range.end.line) + 1 >= cursor.line)
                }
                if !diagnostics.isEmpty {
                    await state.codeActionProvider.requestCodeActionsForLine(
                        uri: fileURL.absoluteString,
                        line: lspLine,
                        character: lspCharacter,
                        diagnostics: diagnostics,
                        content: contentString
                    )
                } else {
                    state.codeActionProvider.clear()
                }
            }

            state.scheduleInlayHintsRefreshIfNeeded(controller: controller)
        }
    }
    
    nonisolated func destroy() {
        print("🗑️ [AutoSave] EditorCoordinator.destroy | state=\(state != nil)")
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
            // 因此自动保存逻辑必须在这里触发。
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
    private static func syncSelections(from controller: TextViewController, to state: EditorState) {
        let selections = controller.textView?.selectionManager.textSelections ?? []
        let mapped = selections
            .map { $0.range }
            .filter { $0.location != NSNotFound }
            .map { MultiCursorSelection(location: $0.location, length: $0.length) }

        guard !mapped.isEmpty else { return }

        // 如果当前正在进行多光标会话，且编辑器回传的选区数量少于 state 中的数量，
        // 不覆盖 state，避免 setSelectedRanges 的 Set 去重导致选区丢失
        if state.multiCursorState.all.count > mapped.count {
            return
        }

        state.setSelections(mapped)
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

        let goToDeclarationItem = buildInjectedItem(
            title: String(localized: "Go to Declaration", table: "LumiEditor"),
            image: "doc.badge.plus"
        ) {
            Self.performGoToDeclaration(textView: textView, state: state)
        }
        menu.insertItem(goToDeclarationItem, at: 0)

        let goToTypeDefinitionItem = buildInjectedItem(
            title: String(localized: "Go to Type Definition", table: "LumiEditor"),
            image: "square.on.square"
        ) {
            Self.performGoToTypeDefinition(textView: textView, state: state)
        }
        menu.insertItem(goToTypeDefinitionItem, at: 0)

        let goToImplementationItem = buildInjectedItem(
            title: String(localized: "Go to Implementation", table: "LumiEditor"),
            image: "arrowtriangle.right"
        ) {
            Self.performGoToImplementation(textView: textView, state: state)
        }
        menu.insertItem(goToImplementationItem, at: 0)

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

        let addNextOccurrenceItem = buildInjectedItem(
            title: String(localized: "Add Next Occurrence", table: "LumiEditor"),
            image: "plus.magnifyingglass"
        ) {
            let currentSelection = textView.selectionManager.textSelections.last?.range ?? NSRange(location: NSNotFound, length: 0)
            if let ranges = state.addNextOccurrence(from: currentSelection) {
                textView.selectionManager.setSelectedRanges(ranges)
            }
        }
        addNextOccurrenceItem.isEnabled = hasSelection
        menu.insertItem(addNextOccurrenceItem, at: 0)

        let selectAllOccurrencesItem = buildInjectedItem(
            title: String(localized: "Select All Occurrences", table: "LumiEditor"),
            image: "text.magnifyingglass"
        ) {
            let currentSelection = textView.selectionManager.textSelections.last?.range ?? NSRange(location: NSNotFound, length: 0)
            if let ranges = state.addAllOccurrences(from: currentSelection) {
                textView.selectionManager.setSelectedRanges(ranges)
            }
        }
        selectAllOccurrencesItem.isEnabled = hasSelection
        menu.insertItem(selectAllOccurrencesItem, at: 0)

        let clearCursorsItem = buildInjectedItem(
            title: String(localized: "Clear Additional Cursors", table: "LumiEditor"),
            image: "cursorarrow.motionlines"
        ) {
            state.clearMultiCursors()
        }
        clearCursorsItem.isEnabled = state.multiCursorState.isEnabled
        menu.insertItem(clearCursorsItem, at: 0)

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

    // MARK: - Add to Chat Action

    private static func performAddSelectionToChat(textView: TextView, state: EditorState) {
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

    private static func performAddLocationToChat(textView: TextView, state: EditorState) {
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

    private static func performGoToDefinition(textView: TextView, state: EditorState) {
        // 获取当前选区作为跳转起点
        let selection = textView.selectionManager.textSelections.first?.range ?? NSRange(location: 0, length: 0)
        guard selection.location != NSNotFound else { return }
        
        // 通过 delegate 复用 Cmd+Click 同一套跳转流程
        Task { @MainActor in
            state.showStatusToast(
                String(localized: "Finding definition...", table: "LumiEditor"),
                level: .info,
                duration: 1.2
            )
            
            await state.jumpDelegate?.performGoToDefinition(forRange: selection)
        }
    }

    private static func performGoToDeclaration(textView: TextView, state: EditorState) {
        let selection = textView.selectionManager.textSelections.first?.range ?? NSRange(location: 0, length: 0)
        guard selection.location != NSNotFound else { return }
        
        Task { @MainActor in
            state.showStatusToast(
                String(localized: "Finding declaration...", table: "LumiEditor"),
                level: .info,
                duration: 1.2
            )
            
            await state.jumpDelegate?.performGoToDeclaration(forRange: selection)
        }
    }

    private static func performGoToTypeDefinition(textView: TextView, state: EditorState) {
        let selection = textView.selectionManager.textSelections.first?.range ?? NSRange(location: 0, length: 0)
        guard selection.location != NSNotFound else { return }
        
        Task { @MainActor in
            state.showStatusToast(
                String(localized: "Finding type definition...", table: "LumiEditor"),
                level: .info,
                duration: 1.2
            )
            
            await state.jumpDelegate?.performGoToTypeDefinition(forRange: selection)
        }
    }

    private static func performGoToImplementation(textView: TextView, state: EditorState) {
        let selection = textView.selectionManager.textSelections.first?.range ?? NSRange(location: 0, length: 0)
        guard selection.location != NSNotFound else { return }
        
        Task { @MainActor in
            state.showStatusToast(
                String(localized: "Finding implementation...", table: "LumiEditor"),
                level: .info,
                duration: 1.2
            )
            
            await state.jumpDelegate?.performGoToImplementation(forRange: selection)
        }
    }

    private static func selectionLocationText(range: NSRange, fullText: NSString, state: EditorState) -> String {
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

    private static func nsRange(from lspRange: LSPRange, in content: String) -> NSRange? {
        guard let start = utf16Offset(for: lspRange.start, in: content),
              let end = utf16Offset(for: lspRange.end, in: content),
              end >= start else {
            return nil
        }
        return NSRange(location: start, length: end - start)
    }

    private static func utf16Offset(for position: Position, in content: String) -> Int? {
        var line = 0
        var utf16Offset = 0
        var lineStartOffset = 0

        for scalar in content.unicodeScalars {
            if line == position.line {
                break
            }
            utf16Offset += scalar.utf16.count
            if scalar == "\n" {
                line += 1
                lineStartOffset = utf16Offset
            }
        }

        guard line == position.line else { return nil }
        return min(lineStartOffset + position.character, content.utf16.count)
    }

    private static func expandedWordRange(at utf16Offset: Int, in content: String) -> NSRange? {
        let ns = content as NSString
        guard utf16Offset >= 0, utf16Offset <= ns.length else { return nil }
        guard ns.length > 0 else { return NSRange(location: 0, length: 0) }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))

        let pivot: Int = {
            if utf16Offset < ns.length { return utf16Offset }
            return max(ns.length - 1, 0)
        }()

        func isAllowed(_ index: Int) -> Bool {
            guard index >= 0, index < ns.length else { return false }
            let c = ns.substring(with: NSRange(location: index, length: 1)).unicodeScalars.first
            return c.map { allowed.contains($0) } ?? false
        }

        var start = pivot
        var end = pivot

        if !isAllowed(pivot), utf16Offset > 0, isAllowed(utf16Offset - 1) {
            start = utf16Offset - 1
            end = utf16Offset - 1
        }

        guard isAllowed(start) else { return NSRange(location: utf16Offset, length: 0) }

        while start > 0, isAllowed(start - 1) {
            start -= 1
        }
        while end + 1 < ns.length, isAllowed(end + 1) {
            end += 1
        }

        return NSRange(location: start, length: end - start + 1)
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
