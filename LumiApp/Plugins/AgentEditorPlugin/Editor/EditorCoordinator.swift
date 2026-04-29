import Foundation
import AppKit
import CodeEditSourceEditor
import CodeEditTextView
import SwiftUI
import LanguageServerProtocol
import os

/// 文本变更协调器
/// 监听 CodeEditSourceEditor 的文本与焦点事件，通知 EditorState 更新脏状态并在失焦时保存
final class EditorCoordinator: TextViewCoordinator, TextViewDelegate, @unchecked Sendable {
    /// 弱引用状态管理器
    private weak var state: EditorState?
    private weak var textViewController: TextViewController?
    private var endEditingObserver: NSObjectProtocol?
    private let bridge = TextViewBridge()
    private let inputRouter = EditorInputRouter()
    /// 跳转定义代理（由外部注入）
    weak var jumpDelegate: EditorJumpToDefinitionDelegate?
    
    init(state: EditorState) {
        self.state = state
    }
    
    // MARK: - TextViewCoordinator
    
    nonisolated func prepareCoordinator(controller: TextViewController) {
        MainActor.assumeIsolated {
            textViewController = controller
            endEditingObserver = bridge.attach(
                controller: controller,
                state: state,
                jumpDelegate: jumpDelegate,
                existingObserver: endEditingObserver
            )
        }
    }
    
    nonisolated func textViewDidChangeText(controller: TextViewController) {
        let payload = MainActor.assumeIsolated {
            let currentText = controller.textView?.string ?? ""
            if EditorPlugin.verbose {
                EditorPlugin.logger.info("\(EditorState.t)文本变更: state=\(self.state != nil), 长度=\(controller.textView?.string.count ?? -1)")
            }
            return (
                state: state,
                inputRouter: inputRouter,
                bridge: bridge,
                currentText: currentText
            )
        }
        Task { @MainActor in
            payload.inputRouter.handleTextDidChange(
                state: payload.state,
                controller: controller,
                currentText: payload.currentText,
                shouldSuppressReconciliation: payload.bridge.consumeSuppressNextTextDidChangeReconciliation(),
                bridge: payload.bridge
            )
        }
    }
    
    nonisolated func textViewDidChangeSelection(controller: TextViewController) {
        let payload = MainActor.assumeIsolated {
            (
                state: state,
                inputRouter: inputRouter,
                bridge: bridge,
                selectionRanges: controller.textView?.selectionManager.textSelections.map(\.range) ?? [],
                cursorPositions: controller.cursorPositions
            )
        }
        guard let state = payload.state else { return }
        Task { @MainActor in
            await payload.inputRouter.handleSelectionDidChange(
                state: state,
                controller: controller,
                selectionRanges: payload.selectionRanges,
                cursorPositions: payload.cursorPositions,
                bridge: payload.bridge
            )
        }
    }
    
    nonisolated func destroy() {
        MainActor.assumeIsolated {
            if EditorPlugin.verbose {
                EditorPlugin.logger.info("\(EditorState.t)Coordinator 销毁: state=\(self.state != nil)")
            }
            bridge.teardown(
                state: &state,
                textViewController: &textViewController,
                observer: &endEditingObserver
            )
        }
    }
    
    func textView(_ textView: TextView, willReplaceContentsIn range: NSRange, with string: String) {
        let state = self.state
        _ = MainActor.assumeIsolated {
            bridge.beginNativeReplacement(
                range: range,
                text: string,
                in: textView,
                captureUndoState: {
                    state?.captureUndoState()
                }
            )
        }
    }
    
    func textView(_ textView: TextView, didReplaceContentsIn range: NSRange, with string: String) {
        let pendingEdit = MainActor.assumeIsolated {
            bridge.consumeNativeReplacement(text: string)
        }
        guard let pendingEdit else { return }
        let state = self.state
        let inputRouter = inputRouter
        Task { @MainActor in
            inputRouter.handleNativeReplacement(
                state: state,
                pendingEdit: pendingEdit,
                textViewString: textView.string
            )
        }
    }
    
}

/// 光标位置协调器
/// 监听光标位置变化，更新行号/列号信息
final class CursorCoordinator: TextViewCoordinator, @unchecked Sendable {
    
    private weak var state: EditorState?
    
    init(state: EditorState) {
        self.state = state
    }
    
    // MARK: - TextViewCoordinator
    
    nonisolated func textViewDidChangeSelection(controller: TextViewController) {
        let payload = MainActor.assumeIsolated {
            (state: state, positions: controller.cursorPositions)
        }
        
        DispatchQueue.main.async {
            if let first = payload.positions.first {
                payload.state?.applyPrimaryCursorObservation(
                    line: first.start.line,
                    column: first.start.column
                )
            } else {
                payload.state?.applyCursorObservation(payload.positions)
            }
        }
    }
    
    nonisolated func prepareCoordinator(controller: TextViewController) {}
    
    nonisolated func controllerDidAppear(controller: TextViewController) {
        MainActor.assumeIsolated {
            if controller.isEditable && controller.isSelectable {
                controller.view.window?.makeFirstResponder(controller.textView)
            }
        }
    }
    
    nonisolated func destroy() { MainActor.assumeIsolated { state = nil } }
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
final class ContextMenuCoordinator: TextViewCoordinator, @unchecked Sendable {

    private weak var state: EditorState?

    init(state: EditorState) {
        self.state = state
    }

    nonisolated func prepareCoordinator(controller: TextViewController) {}

    nonisolated func controllerDidAppear(controller: TextViewController) {
        MainActor.assumeIsolated {
            guard let textView = controller.textView, let state else { return }
            MultiCursorInputInstaller.shared.register(textView: textView, state: state)
            ContextMenuManager.shared.register(textView: textView, state: state)
        }
    }

    nonisolated func destroy() { MainActor.assumeIsolated { state = nil } }
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

        // 从插件注册中心获取所有命令（包括多光标、Chat 集成、LSP 命令等）
        let (line, character) = Self.cursorLSPLineCharacter(textView: textView, state: state)
        let hasSelection = textView.selectionManager.textSelections.contains { !$0.range.isEmpty }
        let commandContext = EditorCommandContext(
            languageId: state.detectedLanguage?.tsName ?? "swift",
            hasSelection: hasSelection,
            line: line,
            character: character
        )
        let presentationModel = state.editorCommandPresentationModel(
            for: commandContext,
            textView: textView,
            categories: EditorCommandCategoryScope.editorContextMenu
        )
        guard !presentationModel.flattenedCommands.isEmpty else { return }

        // 插入分隔符到顶部
        let topSeparator = NSMenuItem.separator()
        topSeparator.tag = injectedSeparatorTag
        menu.insertItem(topSeparator, at: 0)

        var insertIndex = 0

        if !presentationModel.recentCommands.isEmpty {
            menu.insertItem(buildSectionHeader(title: "Recently Used"), at: insertIndex)
            insertIndex += 1
            for command in presentationModel.recentCommands {
                menu.insertItem(buildInjectedItem(for: command, state: state), at: insertIndex)
                insertIndex += 1
            }
            let separator = NSMenuItem.separator()
            separator.tag = injectedSeparatorTag
            menu.insertItem(separator, at: insertIndex)
            insertIndex += 1
        }

        for (sectionIndex, section) in presentationModel.sections.enumerated() {
            menu.insertItem(buildSectionHeader(title: section.title), at: insertIndex)
            insertIndex += 1
            for command in section.commands {
                menu.insertItem(buildInjectedItem(for: command, state: state), at: insertIndex)
                insertIndex += 1
            }
            if sectionIndex < presentationModel.sections.count - 1 {
                let separator = NSMenuItem.separator()
                separator.tag = injectedSeparatorTag
                menu.insertItem(separator, at: insertIndex)
                insertIndex += 1
            }
        }

        // AppKit 的 NSMenu 没有公开的宽度控制 API，这里保留默认布局，
        // 避免依赖不存在的属性导致编译失败。
    }

    private func buildInjectedItem(
        for command: EditorCommandSuggestion,
        state: EditorState
    ) -> NSMenuItem {
        let target = ContextMenuTarget(action: {
            state.performEditorCommand(id: command.id)
        })
        currentTargets.append(target)

        let item = NSMenuItem(
            title: command.title,
            action: #selector(ContextMenuTarget.addToChatClicked),
            keyEquivalent: ""
        )
        item.target = target
        item.tag = injectedItemTag
        item.image = NSImage(systemSymbolName: command.systemImage, accessibilityDescription: nil)
        item.isEnabled = command.isEnabled
        return item
    }

    private func buildSectionHeader(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.tag = injectedItemTag
        item.isEnabled = false
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
