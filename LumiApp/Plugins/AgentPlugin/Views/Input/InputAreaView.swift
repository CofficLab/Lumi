import SwiftUI
import UniformTypeIdentifiers

/// 输入区域视图 - 包含附件预览、编辑器、工具栏
struct InputAreaView: View {
    @EnvironmentObject var agentProvider: AgentProvider
    @EnvironmentObject var commandSuggestionViewModel: CommandSuggestionViewModel

    @Binding var isInputFocused: Bool
    @Binding var isModelSelectorPresented: Bool
    let onSendMessage: () -> Void
    let onImageUpload: () -> Void
    let onDropImage: ([URL]) -> Bool
    let onStopGenerating: () -> Void

    // 动画状态
    @State private var gradientPhase: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            // 输入框容器
            VStack(spacing: 0) {
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
                    onSubmit: onSendMessage,
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
                            commandSuggestionViewModel.isVisible = false
                        } else {
                            onSendMessage()
                        }
                    },
                    isFocused: $isInputFocused,
                    onDrop: onDropImage
                )
                .frame(height: 64)
                .padding(.horizontal, 4)
                .padding(.top, 8)

                // 工具栏 - 传递停止回调
                ChatToolbarView(
                    isModelSelectorPresented: $isModelSelectorPresented,
                    onImageUpload: onImageUpload,
                    onSendMessage: onSendMessage,
                    onStopGenerating: onStopGenerating
                )
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            .overlay(
                // 动态边框 - 处理中时显示动画边框
                processingBorderOverlay
            )
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers: providers)
            }
            .overlay(alignment: .bottomLeading) {
                CommandSuggestionView { suggestion in
                    agentProvider.setCurrentInput(suggestion.command + " ")
                    commandSuggestionViewModel.isVisible = false
                    isInputFocused = true
                }
                .offset(x: 16, y: -60)
            }
        }
        .padding(16)
        // 监听文件拖放通知
        .onFileDroppedToChat { fileURL in
            handleFileDrop(fileURL: fileURL)
        }
    }

    // MARK: - 动态边框效果

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
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
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

    // MARK: - Handle Drop

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        DispatchQueue.main.async {
                            _ = onDropImage([url])
                        }
                    } else if let url = item as? URL {
                        DispatchQueue.main.async {
                            _ = onDropImage([url])
                        }
                    }
                }
                handled = true
            }
        }
        return handled
    }

    /// 处理从项目树拖放的文件
    private func handleFileDrop(fileURL: URL) {
        // 将文件路径作为文本插入到输入框
        let file_path = fileURL.path
        agentProvider.appendInput("\(file_path) ")
    }
}

#Preview {
    InputAreaView(
        isInputFocused: .constant(true),
        isModelSelectorPresented: .constant(false),
        onSendMessage: {},
        onImageUpload: {},
        onDropImage: { _ in true },
        onStopGenerating: {}
    )
    .frame(width: 800)
    .background(Color.black)
    .inRootView()
}
