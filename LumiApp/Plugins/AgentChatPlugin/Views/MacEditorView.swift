import AppKit
import MagicKit
import SwiftUI

/// Mac 编辑器视图
/// 基于 NSTextView 的自定义编辑器，支持快捷键、拖放、焦点管理和动态高度
struct MacEditorView: NSViewRepresentable, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "✏️"
    /// 是否输出详细日志
    nonisolated static let verbose: Bool = false
    /// 最小高度
    static let minHeight: CGFloat = 64
    /// 最大高度
    static let maxHeight: CGFloat = 300

    /// 绑定的文本内容
    @Binding var text: String

    /// 绑定的动态高度
    @Binding var height: CGFloat

    /// 字体设置
    var font: NSFont = .systemFont(ofSize: 15)

    /// 文字颜色（由主题驱动）
    var textColor: NSColor = .textColor

    /// 提交回调：当用户按下 Enter 键时触发
    var onSubmit: () -> Void

    /// 上箭头键回调：用于命令建议列表的上移选择
    var onArrowUp: (() -> Void)? = nil

    /// 下箭头键回调：用于命令建议列表的下移选择
    var onArrowDown: (() -> Void)? = nil

    /// 回车键回调：用于触发命令建议或提交
    var onEnter: (() -> Void)? = nil

    /// 焦点状态绑定
    @Binding var isFocused: Bool

    /// 光标位置绑定
    @Binding var cursorPosition: Int

    /// 是否有可添加的图片正拖过输入框（用于显示「松开可添加」提示）
    @Binding var isImageDragHovering: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = EditorTextView()
        textView.autoresizingMask = [.width]
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.font = font
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.allowsUndo = true
        textView.textColor = textColor
        textView.insertionPointColor = textColor

        // 设置文本容器 - 使用无限高度以便计算内容高度
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainerInset = NSSize(width: 4, height: 4)

        scrollView.documentView = textView
        
        // 初始高度计算
        DispatchQueue.main.async {
            updateHeight(for: textView)
        }
        
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? EditorTextView else { return }

        textView.imageDragHoverHandler = { [weak coordinator = context.coordinator] hovering in
            guard let coordinator else { return }
            DispatchQueue.main.async {
                if coordinator.parent.isImageDragHovering != hovering {
                    coordinator.parent.isImageDragHovering = hovering
                }
            }
        }

        // 同步文字颜色（响应主题切换）
        if textView.textColor != textColor {
            textView.textColor = textColor
            textView.insertionPointColor = textColor
        }

        // 如果用户正在使用输入法组合文字（存在 markedText），不要强制同步，否则会打断输入状态
        if textView.hasMarkedText() {
            return
        }

        // 只有当文本真正不同步时才更新，避免不必要的布局循环
        let textChanged = textView.string != text
        if textChanged {
            // 临时移除 delegate 防止触发 textDidChange 造成循环更新
            textView.delegate = nil
            textView.string = text
            textView.delegate = context.coordinator
        }

        // 将 Swift String.Index (Character 索引) 转换为 UTF-16 索引，匹配 NSTextView 的 selectedRange
        let targetPosition = Self.swiftToUTF16Index(cursorPosition, in: text)
        let needsSelectionUpdate = textView.selectedRange().location != targetPosition || textChanged
        let needsFocus = isFocused && nsView.window.map { $0.firstResponder != textView } ?? false

        // 将高度/选区/焦点的更新推迟到当前 view 更新结束后，避免 "Modifying state during view update"
        if textChanged || needsSelectionUpdate || needsFocus {
            let position = targetPosition
            DispatchQueue.main.async {
                if textChanged, let tv = nsView.documentView as? EditorTextView {
                    updateHeight(for: tv)
                }
                if needsSelectionUpdate, let tv = nsView.documentView as? EditorTextView {
                    tv.setSelectedRange(NSRange(location: position, length: 0))
                }
                if needsFocus, let window = nsView.window, window.firstResponder != textView {
                    window.makeFirstResponder(textView)
                }
            }
        }
    }

    /// 将 Swift Character 索引转换为 UTF-16 索引
    ///
    /// Swift String 的 count 返回 Character 数量，而 NSTextView 的 selectedRange 使用 UTF-16 编码偏移。
    /// 对于 emoji（如 🌳）、某些特殊 Unicode 字符，一个 Character 可能对应多个 UTF-16 code unit，
    /// 导致光标位置错乱。此方法确保索引转换正确。
    static func swiftToUTF16Index(_ swiftIndex: Int, in string: String) -> Int {
        let clampedIndex = min(swiftIndex, string.count)
        guard let index = string.index(string.startIndex, offsetBy: clampedIndex, limitedBy: string.endIndex) else {
            return (string as NSString).length
        }
        return string.utf16.distance(from: string.startIndex, to: index)
    }

    /// 将 UTF-16 索引转换为 Swift Character 索引
    static func utf16ToSwiftIndex(_ utf16Index: Int, in string: String) -> Int {
        let utf16Clamped = min(utf16Index, string.utf16.count)
        let utf16Start = string.utf16.startIndex
        guard let utf16Target = string.utf16.index(utf16Start, offsetBy: utf16Clamped, limitedBy: string.utf16.endIndex) else {
            return string.count
        }
        let swiftTarget = String.Index(utf16Target, within: string) ?? string.endIndex
        return string.distance(from: string.startIndex, to: swiftTarget)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// 计算并更新编辑器高度
    private func updateHeight(for textView: NSTextView) {
        let layoutManager = textView.layoutManager!
        let textContainer = textView.textContainer!
        
        // 确保布局是最新的
        layoutManager.ensureLayout(for: textContainer)
        
        // 获取已使用的矩形
        let usedRect = layoutManager.usedRect(for: textContainer)
        
        // 加上内边距
        let insetHeight = textView.textContainerInset.height * 2
        let contentHeight = usedRect.height + insetHeight
        
        // 限制在最小和最大高度之间
        let newHeight = min(max(contentHeight, Self.minHeight), Self.maxHeight)
        
        // 更新滚动条状态
        if let scrollView = textView.enclosingScrollView {
            scrollView.hasVerticalScroller = contentHeight > Self.maxHeight
        }
        
        // 更新高度绑定
        if height != newHeight {
            DispatchQueue.main.async {
                self.height = newHeight
            }
        }
    }
}

// MARK: - Coordinator

extension MacEditorView {
    /// 协调器：处理文本变化和按键事件
    class Coordinator: NSObject, NSTextViewDelegate {
        /// 父视图引用
        var parent: MacEditorView

        init(_ parent: MacEditorView) {
            self.parent = parent
        }

        /// 文本变化回调
        /// - Parameter notification: 通知对象
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            
            // 同步光标位置：将 NSTextView 的 UTF-16 索引转换为 Swift Character 索引
            let utf16Location = textView.selectedRange().location
            let swiftLocation = MacEditorView.utf16ToSwiftIndex(utf16Location, in: textView.string)
            if parent.cursorPosition != swiftLocation {
                parent.cursorPosition = swiftLocation
            }
            
            // 文本变化时更新高度
            parent.updateHeight(for: textView)
        }

        /// 按键事件处理
        /// - Parameters:
        ///   - textView: 文本视图
        ///   - commandSelector: 命令选择器
        /// - Returns: 是否已处理该命令
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if let onEnter = parent.onEnter {
                    onEnter()
                    return true
                }
                if let event = NSApp.currentEvent,
                   event.modifierFlags.contains(.shift)
                {
                    return false // 允许换行 (Shift + Enter)
                }
                parent.onSubmit()
                return true // 阻止换行并触发提交
            } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
                if let onArrowUp = parent.onArrowUp {
                    onArrowUp()
                    return true
                }
            } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
                if let onArrowDown = parent.onArrowDown {
                    onArrowDown()
                    return true
                }
            }
            return false
        }
    }
}

// MARK: - EditorTextView

/// 编辑器文本视图
/// 扩展 NSTextView 以支持文件拖放功能
class EditorTextView: NSTextView, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "📝"
    /// 是否输出详细日志
    nonisolated static let verbose: Bool = false

    /// 与 `InputAreaView.handleFileDrop` 中作为图片附件处理的扩展名一致
    private static let imagePathExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic",
    ]

    /// 拖放悬停状态回调（主线程更新 SwiftUI）
    var imageDragHoverHandler: ((Bool) -> Void)?

    /// 拖放数据是否为「会按图片附件处理」的文件（与 `performDragOperation` + `handleFileDrop` 对齐）
    private func draggingInfoContainsChatImageFile(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            return urls.contains { Self.imagePathExtensions.contains($0.pathExtension.lowercased()) }
        }
        if let strings = pasteboard.readObjects(forClasses: [NSString.self], options: nil) as? [String],
           let first = strings.first,
           first.hasPrefix("/")
        {
            let ext = URL(fileURLWithPath: first).pathExtension.lowercased()
            return Self.imagePathExtensions.contains(ext)
        }
        return false
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if draggingInfoContainsChatImageFile(sender) {
            imageDragHoverHandler?(true)
            return .copy
        }
        imageDragHoverHandler?(false)
        return super.draggingEntered(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if draggingInfoContainsChatImageFile(sender) {
            imageDragHoverHandler?(true)
            return .copy
        }
        imageDragHoverHandler?(false)
        return super.draggingUpdated(sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        imageDragHoverHandler?(false)
        super.draggingExited(sender)
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        imageDragHoverHandler?(false)
        super.concludeDragOperation(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        
        if Self.verbose {
            AgentChatPlugin.logger.info("\(Self.t)📎 performDragOperation 被调用")
        }

        // 首先尝试读取文件 URL
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           !urls.isEmpty
        {
            if Self.verbose {
                AgentChatPlugin.logger.info("\(Self.t)📎 读取到 \(urls.count) 个 URL: \(urls.first?.path ?? "unknown")")
            }
            // 发送通知让 InputAreaView 处理
            NotificationCenter.postFileDroppedToChat(fileURL: urls.first!)
            return true
        }
        
        // 尝试读取纯文本（用于从项目树拖放的文件路径字符串）
        if let strings = pasteboard.readObjects(forClasses: [NSString.self], options: nil) as? [String],
           !strings.isEmpty,
           let firstString = strings.first
        {
            if Self.verbose {
                AgentChatPlugin.logger.info("\(Self.t)📎 读取到字符串: \(firstString)")
            }
            // 如果是绝对路径，发送通知
            if firstString.hasPrefix("/") {
                NotificationCenter.postFileDroppedToChat(fileURL: URL(fileURLWithPath: firstString))
                return true
            }
        }
        
        if Self.verbose {
            AgentChatPlugin.logger.info("\(Self.t)⚠️ 没有读取到有效的拖放数据")
        }

        return super.performDragOperation(sender)
    }
}

// MARK: - Preview

#Preview("Editor") {
    struct PreviewWrapper: View {
        @State private var text = "Hello, World!"
        @State private var height: CGFloat = 64
        @State private var isFocused = true
        @State private var cursorPosition = 0
        @State private var isImageDragHovering = false

        var body: some View {
            VStack {
                MacEditorView(
                    text: $text,
                    height: $height,
                    onSubmit: {},
                    onArrowUp: {},
                    onArrowDown: {},
                    onEnter: {},
                    isFocused: $isFocused,
                    cursorPosition: $cursorPosition,
                    isImageDragHovering: $isImageDragHovering
                )
                .frame(height: height)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)

                Text("Height: \(Int(height))")
                    .font(.caption)
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
            }
            .padding()
            .frame(width: 400)
        }
    }

    return PreviewWrapper()
        .inRootView()
}
