import MagicKit
import SwiftUI
import OSLog
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
    nonisolated static let verbose = true

    /// 智能体提供者
    @EnvironmentObject var agentProvider: AgentProvider

    /// 处理状态 ViewModel
    @EnvironmentObject var processingStateViewModel: ProcessingStateViewModel

    /// 命令建议 ViewModel
    @EnvironmentObject var commandSuggestionViewModel: CommandSuggestionViewModel

    /// 输入框本地状态 ViewModel（与 agentProvider 解耦，避免击键触发全局重庆染）
    @ObservedObject var inputViewModel: InputViewModel

    /// 输入框是否处于聚焦状态
    @Binding var isInputFocused: Bool

    /// 模型选择器是否显示
    @Binding var isModelSelectorPresented: Bool

    /// 编辑器动态高度
    @State private var editorHeight: CGFloat = MacEditorView.minHeight

    var body: some View {
        VStack(spacing: 8) {
            // 附件预览区域
            if !agentProvider.pendingAttachments.isEmpty {
                AttachmentPreviewView(
                    attachments: agentProvider.pendingAttachments,
                    onRemove: { id in
                        agentProvider.removeAttachment(id: id)
                    }
                )
            }

            // 编辑器 - 使用动态高度
            MacEditorView(
                text: $inputViewModel.text,
                height: $editorHeight,
                onSubmit: {
                    let text = inputViewModel.text
                    inputViewModel.clear()
                    agentProvider.sendMessage(input: text)
                    // 发送后重置高度
                    editorHeight = MacEditorView.minHeight
                },
                onArrowUp: {
                    if commandSuggestionViewModel.isVisible {
                        commandSuggestionViewModel.selectPrevious()
                    }
                },
                onArrowDown: {
                    if commandSuggestionViewModel.isVisible {
                        commandSuggestionViewModel.selectNext()
                    }
                },
                onEnter: {
                    if commandSuggestionViewModel.isVisible,
                       let suggestion = commandSuggestionViewModel.getCurrentSuggestion() {
                        inputViewModel.set(suggestion.command + " ")
                        commandSuggestionViewModel.setIsVisible(false)
                    } else {
                        let text = inputViewModel.text
                        inputViewModel.clear()
                        agentProvider.sendMessage(input: text)
                        // 发送后重置高度
                        editorHeight = MacEditorView.minHeight
                    }
                },
                isFocused: $isInputFocused,
                cursorPosition: $inputViewModel.cursorPosition
            )
            .frame(height: editorHeight)
            .padding(.horizontal, 4)
            .padding(.top, 8)
            // 添加高度变化动画
            .animation(.easeInOut(duration: 0.15), value: editorHeight)
            // 监听文本变化以触发命令建议
            .onChange(of: inputViewModel.text) { newValue in
                commandSuggestionViewModel.updateSuggestions(for: newValue)
            }

            // 工具栏
            ChatToolbarView(
                inputViewModel: inputViewModel,
                isModelSelectorPresented: $isModelSelectorPresented
            )
        }
        .background(.background)
        .cornerRadius(12)
        .overlay(
            // 动态边框 - 处理中时显示动画边框
            processingBorderOverlay
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .overlay(alignment: .bottomLeading) {
            CommandSuggestionView { suggestion in
                inputViewModel.set(suggestion.command + " ")
                commandSuggestionViewModel.setIsVisible(false)
                isInputFocused = true
            }
            .offset(x: 16, y: -60)
        }
        // 监听文件拖放通知（由 MacEditorView 发送）
        .onFileDroppedToChat { fileURL in
            handleFileDrop(fileURL: fileURL)
        }
    }
}

// MARK: - View

extension InputAreaView {
    /// 处理中的动态边框叠加层
    @ViewBuilder
    private var processingBorderOverlay: some View {
        if processingStateViewModel.isProcessing {
            // 暂时禁用无限动画边框，避免持续触发渲染事务
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    Color.blue.opacity(0.35),
                    lineWidth: 2
                )
        } else {
            // 默认静态边框
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.1), lineWidth: 1)
        }
    }
}

// MARK: - Action

extension InputAreaView {
    /// 处理从项目树拖放的文件
    /// - Parameter fileURL: 拖放的文件 URL
    private func handleFileDrop(fileURL: URL) {
        if Self.verbose {
            os_log("\(Self.t)📎 handleFileDrop: \(fileURL.path)")
        }
        
        // 检查是否是图片文件
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic"]
        let fileExtension = fileURL.pathExtension.lowercased()

        if imageExtensions.contains(fileExtension) {
            // 图片文件：作为附件上传
            agentProvider.handleImageUpload(url: fileURL)
        } else {
            // 非图片文件：将文件路径插入到输入框
            // 使用 append 方法自动处理空格和光标位置
            inputViewModel.append(fileURL.path)
        }
        
        if Self.verbose {
            os_log("\(Self.t)✅ handleFileDrop 完成，text.count=\(inputViewModel.text.count), cursorPosition=\(inputViewModel.cursorPosition)")
        }
    }
}

// MARK: - Preview
