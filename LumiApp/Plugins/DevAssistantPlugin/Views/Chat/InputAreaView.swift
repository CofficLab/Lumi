import SwiftUI
import UniformTypeIdentifiers

/// 输入区域视图 - 包含附件预览、编辑器、工具栏和快捷短语
struct InputAreaView: View {
    @ObservedObject var viewModel: AssistantViewModel
    @Binding var isInputFocused: Bool
    @Binding var isModelSelectorPresented: Bool
    let onSendMessage: () -> Void
    let onImageUpload: () -> Void
    let onDropImage: ([URL]) -> Bool

    var body: some View {
        VStack(spacing: 0) {
            // 输入框容器
            VStack(spacing: 0) {
                // 附件预览区域
                if !viewModel.pendingAttachments.isEmpty {
                    AttachmentPreviewView(
                        attachments: viewModel.pendingAttachments,
                        onRemove: { id in
                            viewModel.removeAttachment(id: id)
                        }
                    )
                }

                // 编辑器
                MacEditorView(
                    text: $viewModel.currentInput,
                    onSubmit: onSendMessage,
                    onArrowUp: {
                        if viewModel.commandSuggestionViewModel.isVisible {
                            viewModel.commandSuggestionViewModel.selectPrevious()
                        }
                    },
                    onArrowDown: {
                        if viewModel.commandSuggestionViewModel.isVisible {
                            viewModel.commandSuggestionViewModel.selectNext()
                        }
                    },
                    onEnter: {
                        if viewModel.commandSuggestionViewModel.isVisible,
                           let suggestion = viewModel.commandSuggestionViewModel.getCurrentSuggestion() {
                            viewModel.currentInput = suggestion.command + " "
                            viewModel.commandSuggestionViewModel.isVisible = false
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

                // 工具栏
                ChatToolbarView(
                    viewModel: viewModel,
                    isModelSelectorPresented: $isModelSelectorPresented,
                    onImageUpload: onImageUpload,
                    onSendMessage: onSendMessage
                )
                
                // 快捷短语区域（英文 Commit 和中文 Commit）
                if viewModel.isProjectSelected {
                    QuickPhrasesView(
                        onPhraseSelected: { prompt in
                            viewModel.currentInput = prompt
                            isInputFocused = true
                        },
                        projectName: $viewModel.currentProjectName,
                        projectPath: $viewModel.currentProjectPath,
                        isProjectSelected: $viewModel.isProjectSelected
                    )
                    .padding(.top, 8)
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers: providers)
            }
            .overlay(alignment: .bottomLeading) {
                CommandSuggestionView(viewModel: viewModel.commandSuggestionViewModel) { suggestion in
                    viewModel.currentInput = suggestion.command + " "
                    viewModel.commandSuggestionViewModel.isVisible = false
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
        viewModel.currentInput += "\(file_path) "
    }
}

#Preview {
    InputAreaView(
        viewModel: AssistantViewModel(),
        isInputFocused: .constant(true),
        isModelSelectorPresented: .constant(false),
        onSendMessage: {},
        onImageUpload: {},
        onDropImage: { _ in true }
    )
    .frame(width: 800)
    .background(Color.black)
}
