import SwiftUI

/// Dev Assistant 主视图 - 聊天界面
struct DevAssistantView: View {
    @StateObject private var viewModel = DevAssistantViewModel()
    @State private var isInputFocused: Bool = false
    @State private var isSettingsPresented = false
    @State private var isModelSelectorPresented = false

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Chat History
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages.filter { $0.role != .system }) { msg in
                            ChatBubble(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages) { _, _ in
                    if let lastId = viewModel.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }

            // MARK: - Input Area
            VStack(spacing: 0) {
                GlassDivider()
                HStack(alignment: .bottom) {
                    // 供应商选择器
                    VStack(spacing: 0) {
                        Spacer()
                        Button(action: {
                            isModelSelectorPresented = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "globe")
                                    .font(.system(size: 16))
                                Text(viewModel.currentModel)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                            .padding(4)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $isModelSelectorPresented, arrowEdge: .top) {
                            ModelSelectorView(viewModel: viewModel)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 4)

                    MacEditorView(
                        text: $viewModel.currentInput,
                        onSubmit: {
                            viewModel.sendMessage()
                        },
                        isFocused: $isInputFocused
                    )
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(8)
                        .frame(minHeight: 40, maxHeight: 120)
                        .fixedSize(horizontal: false, vertical: true)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(DesignTokens.Color.semantic.textTertiary.opacity(0.2), lineWidth: 1)
                        )

                    if viewModel.isProcessing {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 4)
                    }

                    GlassButton(systemImage: "paperplane.fill", style: .primary) {
                        viewModel.sendMessage()
                    }
                    .disabled(viewModel.currentInput.isEmpty || viewModel.isProcessing)
                    .frame(width: 44, height: 44)
                }
                .padding(12)
                .background(DesignTokens.Material.glass)
            }
            .frame(height: 56)
        }
        .onAppear {
            isInputFocused = true
        }
        .overlay {
            // MARK: - Permission Request Overlay
            if let request = viewModel.pendingPermissionRequest {
                PermissionRequestView(
                    request: request,
                    onAllow: {
                        viewModel.respondToPermissionRequest(allowed: true)
                    },
                    onDeny: {
                        viewModel.respondToPermissionRequest(allowed: false)
                    }
                )
            }
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(DevAssistantPlugin.navigationId)
        .hideTabPicker()
        .inRootView()
        .withDebugBar()
}
