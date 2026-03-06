import MagicKit
import SwiftUI
import UniformTypeIdentifiers

/// 输入区域视图 - 包含附件预览、编辑器、工具栏
///
/// ## 注意
/// 此视图不包含 `PendingMessagesView`，后者已移到外层视图 (`InputView`) 中。
/// 这样设计是为了避免待发送消息队列的变化导致输入框重新渲染而丢失焦点。
struct InputAreaView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "💬"
    /// 是否输出详细日志
    nonisolated static let verbose = false

    /// 智能体提供者
    @EnvironmentObject var agentProvider: AgentProvider

    /// 命令建议 ViewModel
    @EnvironmentObject var commandSuggestionViewModel: CommandSuggestionViewModel

    /// 输入框是否处于聚焦状态
    @Binding var isInputFocused: Bool

    /// 模型选择器是否显示
    @Binding var isModelSelectorPresented: Bool

    /// 动画相位状态（用于渐变边框动画）
    @State private var gradientPhase: CGFloat = 0

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

            // 编辑器
            MacEditorView(
                text: Binding(
                    get: { agentProvider.currentInput },
                    set: { agentProvider.setCurrentInput($0) }
                ),
                onSubmit: {
                    agentProvider.sendMessage()
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
                        agentProvider.setCurrentInput(suggestion.command + " ")
                        commandSuggestionViewModel.setIsVisible(false)
                    } else {
                        agentProvider.sendMessage()
                    }
                },
                isFocused: $isInputFocused,
                onDrop: { urls in
                    handleDrop(urls: urls)
                }
            )
            .frame(height: 64)
            .padding(.horizontal, 4)
            .padding(.top, 8)

            // 工具栏
            ChatToolbarView(
                isModelSelectorPresented: $isModelSelectorPresented
            )
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            // 动态边框 - 处理中时显示动画边框
            processingBorderOverlay
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDropProviders(providers: providers)
        }
        .overlay(alignment: .bottomLeading) {
            CommandSuggestionView { suggestion in
                agentProvider.setCurrentInput(suggestion.command + " ")
                commandSuggestionViewModel.setIsVisible(false)
                isInputFocused = true
            }
            .offset(x: 16, y: -60)
        }
        // 监听文件拖放通知
        .onFileDroppedToChat { fileURL in
            handleFileDrop(fileURL: fileURL)
        }
        // 视图出现时启动动画
        .onAppear(perform: onAppear)
    }
}

// MARK: - View

extension InputAreaView {
    /// 处理中的动态边框叠加层
    @ViewBuilder
    private var processingBorderOverlay: some View {
        if agentProvider.isProcessing {
            // 动态渐变边框
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.3),
                            Color.purple.opacity(0.5),
                            Color.blue.opacity(0.3)
                        ]),
                        center: .center,
                        startAngle: .degrees(gradientPhase * 360),
                        endAngle: .degrees(360.0 + (gradientPhase * 360.0))
                    ),
                    lineWidth: 2
                )
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever()) {
                        gradientPhase = 1
                    }
                }
                .onDisappear {
                    gradientPhase = 0
                }
        } else {
            // 默认静态边框
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.1), lineWidth: 1)
        }
    }
}

// MARK: - Event Handler

extension InputAreaView {
    /// 视图出现时的事件处理
    /// 启动渐变边框动画
    func onAppear() {
        gradientPhase = 0
    }
}

// MARK: - Action

extension InputAreaView {
    /// 处理图片选择
    private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]

        panel.begin { response in
            if response == .OK, let url = panel.url {
                agentProvider.handleImageUpload(url: url)
            }
        }
    }

    /// 处理从项目树拖放的文件
    /// - Parameter fileURL: 拖放的文件 URL
    private func handleFileDrop(fileURL: URL) {
        // 将文件路径作为文本插入到输入框
        let file_path = fileURL.path
        agentProvider.appendInput("\(file_path) ")
    }

    /// 处理拖放操作（URL 列表）
    /// - Parameter urls: 拖放的 URL 列表
    private func handleDrop(urls: [URL]) -> Bool {
        for url in urls {
            handleDroppedFile(url: url)
        }
        return true
    }

    /// 处理拖放操作（NSItemProvider 列表）
    /// - Parameter providers: NSItemProvider 列表
    /// - Returns: 是否成功处理
    private func handleDropProviders(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        DispatchQueue.main.async {
                            self.handleDroppedFile(url: url)
                        }
                    } else if let url = item as? URL {
                        DispatchQueue.main.async {
                            self.handleDroppedFile(url: url)
                        }
                    }
                }
                handled = true
            }
        }
        return handled
    }

    /// 处理拖放的文件
    /// 根据文件类型决定是插入图片还是文件路径
    /// - Parameter url: 拖放的文件 URL
    private func handleDroppedFile(url: URL) {
        // 检查是否是图片文件
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic"]
        let fileExtension = url.pathExtension.lowercased()

        if imageExtensions.contains(fileExtension) {
            // 图片文件：作为附件上传
            agentProvider.handleImageUpload(url: url)
        } else {
            // 非图片文件：将文件路径插入到输入框
            let filePath = url.path
            agentProvider.appendInput("\(filePath) ")
        }
    }
}

// MARK: - Preview

#Preview("Input Area") {
    InputAreaView(
        isInputFocused: .constant(true),
        isModelSelectorPresented: .constant(false)
    )
    .frame(width: 800, height: 200)
    .background(Color.black)
    .inRootView()
}