import SwiftUI

/// Dev Assistant 主视图 - 聊天界面
struct DevAssistantView: View {
    @StateObject private var viewModel = DevAssistantViewModel()
    @State private var isInputFocused: Bool = false
    @State private var isSettingsPresented = false

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
                        Menu {
                            Picker("Provider", selection: $viewModel.selectedProvider) {
                                ForEach(LLMProvider.allCases) { provider in
                                    Text(provider.rawValue).tag(provider)
                                }
                            }
                            GlassDivider()
                            // 快速模型编辑？或者只显示当前模型
                            Text("Model: \(viewModel.currentModel)")
                                .font(.caption)
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        } label: {
                            Image(systemName: "globe")
                                .font(.system(size: 20))
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 30, height: 30)
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
