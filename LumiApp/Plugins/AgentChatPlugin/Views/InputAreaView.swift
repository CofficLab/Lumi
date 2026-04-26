import AppKit
import MagicKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Input Events

/// 输入区域视图 - 包含附件预览、编辑器、工具栏
///
/// ## 注意
/// 此视图不包含 `PendingMessagesView`，后者已移到外层视图 (`InputView`) 中。
/// 这样设计是为了避免待发送消息队列的变化导致输入框重新渲染而丢失焦点。
struct InputAreaView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "💬"
    /// 是否输出详细日志
    nonisolated static let verbose: Bool = false
    /// 待发送附件
    @EnvironmentObject private var agentAttachmentsVM: AttachmentsVM

    /// 入队器：只负责把输入入队
    @EnvironmentObject private var inputQueueVM: InputQueueVM

    /// 会话管理 ViewModel
    @EnvironmentObject var ConversationVM: ConversationVM

    /// 命令建议 ViewModel
    @EnvironmentObject var commandSuggestionViewModel: CommandSuggestionVM

    /// 输入框本地状态 ViewModel（与 agentProvider 解耦，避免击键触发全局重庆染）
    @ObservedObject var inputViewModel: InputViewModel

    /// 输入框是否处于聚焦状态
    @Binding var isInputFocused: Bool

    /// 模型选择器是否显示
    @Binding var isModelSelectorPresented: Bool

    /// 编辑器动态高度
    @State private var editorHeight: CGFloat = MacEditorView.minHeight

    /// 图片文件正拖过输入框（显示「松开可添加」提示，由 `NSTextView` 更新）
    @State private var isImageDragHovering = false

    /// 图片拖过附件预览条时显示同一提示（SwiftUI 区不会触发 `NSTextView` 的 dragging 回调）
    @State private var isAttachmentStripImageDragHint = false

    /// 是否允许输入/发送（必须先选中会话）
    private var canChat: Bool {
        ConversationVM.selectedConversationId != nil
    }

    var body: some View {
        VStack(spacing: 8) {
            // 附件预览区域（SwiftUI 会拦截命中测试；需单独 onDrop，否则拖放无法到达下方 NSTextView）
            if !agentAttachmentsVM.pendingAttachments.isEmpty {
                VStack(spacing: 0) {
                    AttachmentPreviewView(
                        attachments: agentAttachmentsVM.pendingAttachments,
                        onRemove: { id in
                            agentAttachmentsVM.removeAttachment(id: id)
                        }
                    )
                    .frame(maxWidth: .infinity)
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                    // 与下方编辑器的 spacing: 8 对齐，避免拖到夹缝无效
                    Color.clear
                        .frame(height: 8)
                        .contentShape(Rectangle())
                }
                .overlay {
                    if canChat, isAttachmentStripImageDragHint {
                        imageDropHoverOverlay
                    }
                }
                .animation(.easeInOut(duration: 0.12), value: isAttachmentStripImageDragHint)
                .onDrop(
                    of: [UTType.fileURL, UTType.utf8PlainText],
                    delegate: ChatAttachmentStripDropDelegate(
                        isImageHintVisible: $isAttachmentStripImageDragHint,
                        canAcceptDrop: { canChat },
                        shouldShowImageHint: { InputAreaView.dropInfoSuggestsChatImage($0) },
                        onPerform: { acceptChatFileDropFromProviders($0) }
                    )
                )
            }

            // 编辑器 - 使用动态高度
            macEditorView
                .frame(height: editorHeight)
                .padding(.horizontal, 4)
                .padding(.top, 8)
                .allowsHitTesting(canChat)
                .opacity(canChat ? 1 : 0.6)
                .accessibilityLabel(String(localized: "Message Input", table: "AgentInput"))
                .accessibilityHint(String(localized: "Message Input Hint", table: "AgentInput"))

            // 工具栏
            ChatToolbarView(
                inputViewModel: inputViewModel,
                isModelSelectorPresented: $isModelSelectorPresented
            )
            .allowsHitTesting(canChat)
            .opacity(canChat ? 1 : 0.6)
            .accessibilityLabel(String(localized: "Chat Toolbar", table: "AgentInput"))
            .accessibilityHint(String(localized: "Chat Toolbar Hint", table: "AgentInput"))
        }
        .background(.background)
        .overlay(RoundedRectangle(cornerRadius: 0)
            .stroke(Color.black.opacity(0.1), lineWidth: 1))
        .overlay {
            if !canChat {
                noConversationOverlay
            }
        }
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .overlay(alignment: .bottomLeading) {
            commandSuggestionOverlay
        }
        // 监听文件拖放通知（由 MacEditorView 发送）
        .onFileDroppedToChat { fileURL in
            handleFileDrop(fileURL: fileURL)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Input Area", table: "AgentInput"))
    }
}

// MARK: - View

extension InputAreaView {
    /// 无会话时的遮罩层
    private var noConversationOverlay: some View {
        ZStack {
            // 半透明背景，盖住输入区域，防止误操作
            RoundedRectangle(cornerRadius: 12)
                .fill(.background.opacity(0.9))

            VStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)

                Text(String(localized: "Please create or select a conversation first", table: "AgentInput"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 16)
        }
    }

    /// 命令建议浮层
    private var commandSuggestionOverlay: some View {
        CommandSuggestionView { suggestion in
            inputViewModel.set(suggestion.command + " ")
            commandSuggestionViewModel.setIsVisible(false)
            isInputFocused = true
        }
        .offset(x: 16, y: -60)
    }
}

// MARK: - Editor View

extension InputAreaView {
    /// 编辑器视图（提取以避免类型检查超时）
    private var macEditorView: some View {
        MacEditorView(
            text: $inputViewModel.text,
            height: $editorHeight,
            onSubmit: handleSubmit,
            onArrowUp: handleArrowUp,
            onArrowDown: handleArrowDown,
            onEnter: handleEnter,
            isFocused: $isInputFocused,
            cursorPosition: $inputViewModel.cursorPosition,
            isImageDragHovering: $isImageDragHovering
        )
        // 添加高度变化动画
        .animation(.easeInOut(duration: 0.15), value: editorHeight)
        // 监听文本变化以触发命令建议
        .onChange(of: inputViewModel.text) {
            commandSuggestionViewModel.updateSuggestions(for: inputViewModel.text)
        }
        .overlay {
            if canChat, isImageDragHovering {
                imageDropHoverOverlay
            }
        }
        .animation(.easeInOut(duration: 0.12), value: isImageDragHovering)
    }

    /// 图片拖入输入框时的松开提示
    private var imageDropHoverOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [7, 5]),
                    antialiased: true
                )
                .foregroundStyle(.secondary.opacity(0.65))

            VStack(spacing: 8) {
                Image(systemName: "photo.badge.plus")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)

                Text(String(localized: "Release to add image to chat", table: "AgentInput"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }
}

// MARK: - Editor Actions

extension InputAreaView {
    /// 提交输入
    private func handleSubmit() {
        guard canChat else { return }
        let text = inputViewModel.text
        inputViewModel.clear()
        inputQueueVM.enqueueText(text)
        // 发送后重置高度
        editorHeight = MacEditorView.minHeight
    }

    /// 处理上箭头键
    private func handleArrowUp() {
        if commandSuggestionViewModel.isVisible {
            commandSuggestionViewModel.selectPrevious()
        }
    }

    /// 处理下箭头键
    private func handleArrowDown() {
        if commandSuggestionViewModel.isVisible {
            commandSuggestionViewModel.selectNext()
        }
    }

    /// 处理回车键
    private func handleEnter() {
        guard canChat else { return }

        if commandSuggestionViewModel.isVisible,
           let suggestion = commandSuggestionViewModel.getCurrentSuggestion() {
            // 选择命令建议
            inputViewModel.set(suggestion.command + " ")
            commandSuggestionViewModel.setIsVisible(false)
        } else {
            // 发送消息
            let text = inputViewModel.text
            inputViewModel.clear()
            inputQueueVM.enqueueText(text)
            // 发送后重置高度
            editorHeight = MacEditorView.minHeight
        }
    }
}

// MARK: - Action

extension InputAreaView {
    /// 与 `handleFileDrop` / `EditorTextView` 中「按图片附件处理」的扩展名一致
    fileprivate static let chatImagePathExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic",
    ]

    /// 根据 `DropInfo` 判断是否应显示「松开添加图片」提示（附件条等 SwiftUI 拖放区）
    fileprivate static func dropInfoSuggestsChatImage(_ info: DropInfo) -> Bool {
        let imageUTTypes: [UTType] = [.image, .jpeg, .png, .gif, .webP, .heic, .tiff, .bmp]
        if imageUTTypes.contains(where: { !info.itemProviders(for: [$0]).isEmpty }) {
            return true
        }
        for provider in info.itemProviders(for: [.item]) {
            if let suggested = provider.suggestedName {
                let ext = (suggested as NSString).pathExtension.lowercased()
                if chatImagePathExtensions.contains(ext) {
                    return true
                }
            }
            for id in provider.registeredTypeIdentifiers {
                if let ut = UTType(id), ut.conforms(to: .image) {
                    return true
                }
            }
        }
        return false
    }

    /// 在附件预览等 SwiftUI 区域内接受拖放（Finder 为 fileURL，项目树为 UTF8 路径字符串）
    private func acceptChatFileDropFromProviders(_ providers: [NSItemProvider]) -> Bool {
        guard canChat, let provider = providers.first else { return false }
        if provider.canLoadObject(ofClass: URL.self) {
            provider.loadObject(ofClass: URL.self) { item, _ in
                guard let url = item as? URL else { return }
                Task { @MainActor in
                    handleFileDrop(fileURL: url)
                }
            }
            return true
        }
        if provider.canLoadObject(ofClass: String.self) {
            provider.loadObject(ofClass: String.self) { item, _ in
                guard let path = item as? String, path.hasPrefix("/") else { return }
                Task { @MainActor in
                    handleFileDrop(fileURL: URL(fileURLWithPath: path))
                }
            }
            return true
        }
        return false
    }

    /// 处理从项目树拖放的文件
    /// - Parameter fileURL: 拖放的文件 URL
    private func handleFileDrop(fileURL: URL) {
        if Self.verbose {
            AgentChatPlugin.logger.info("\(Self.t)📎 handleFileDrop: \(fileURL.path)")
        }

        // 检查是否是图片文件
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic"]
        let fileExtension = fileURL.pathExtension.lowercased()

        if imageExtensions.contains(fileExtension) {
            // 图片文件：作为附件上传
            agentAttachmentsVM.handleImageUpload(url: fileURL)
        } else {
            // 非图片文件：将文件路径插入到输入框
            // 使用 append 方法自动处理空格和光标位置
            inputViewModel.append(fileURL.path)
        }

        if Self.verbose {
            AgentChatPlugin.logger.info("\(Self.t)✅ handleFileDrop 完成，text.count=\(inputViewModel.text.count), cursorPosition=\(inputViewModel.cursorPosition)")
        }
    }
}

// MARK: - Attachment strip drop

/// 附件预览条拖放：执行落盘逻辑，并在拖入图片时驱动与编辑器一致的「松开添加」提示
private struct ChatAttachmentStripDropDelegate: DropDelegate {
    @Binding var isImageHintVisible: Bool
    var canAcceptDrop: () -> Bool
    var shouldShowImageHint: (DropInfo) -> Bool
    var onPerform: ([NSItemProvider]) -> Bool

    func validateDrop(info: DropInfo) -> Bool {
        guard canAcceptDrop() else { return false }
        return !info.itemProviders(for: [UTType.fileURL]).isEmpty
            || !info.itemProviders(for: [UTType.utf8PlainText]).isEmpty
    }

    func dropEntered(info: DropInfo) {
        updateHint(info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updateHint(info)
        return validateDrop(info: info) ? DropProposal(operation: .copy) : DropProposal(operation: .forbidden)
    }

    func dropExited(info: DropInfo) {
        isImageHintVisible = false
    }

    func performDrop(info: DropInfo) -> Bool {
        isImageHintVisible = false
        let providers = info.itemProviders(for: [UTType.fileURL, UTType.utf8PlainText])
        guard !providers.isEmpty else { return false }
        return onPerform(providers)
    }

    private func updateHint(_ info: DropInfo) {
        guard validateDrop(info: info) else {
            isImageHintVisible = false
            return
        }
        isImageHintVisible = shouldShowImageHint(info)
    }
}

// MARK: - Preview
