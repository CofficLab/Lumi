import SwiftUI

/// Dev Assistant 主视图 - 聊天界面
struct DevAssistantView: View {
    @StateObject private var viewModel = DevAssistantViewModel()
    @State private var isInputFocused: Bool = false
    @State private var isModelSelectorPresented = false
    @State private var isProjectSelectorPresented = false
    @State private var showQuickPhrases: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.accentColor)
                        .frame(width: 36, height: 36)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.currentProjectName.isEmpty ? "Dev Assistant" : viewModel.currentProjectName)
                            .font(DesignTokens.Typography.body)
                            .fontWeight(.medium)
                            .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                        Text(viewModel.currentProjectPath.isEmpty ? "Ready to help" : viewModel.currentProjectPath)
                            .font(DesignTokens.Typography.caption1)
                            .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer()

                    // 语言选择器
                    Menu {
                        ForEach(LanguagePreference.allCases) { lang in
                            Button(action: {
                                withAnimation {
                                    viewModel.languagePreference = lang
                                }
                            }) {
                                HStack {
                                    Text(lang.displayName)
                                    if viewModel.languagePreference == lang {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "globe")
                                .font(.system(size: 12))
                            Text(viewModel.languagePreference.displayName)
                                .font(DesignTokens.Typography.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(6)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 70)

                    // 项目管理按钮
                    Button(action: {
                        isProjectSelectorPresented = true
                    }) {
                        Image(systemName: "folder.badge.gearshape")
                            .font(.system(size: 14))
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(Color.black.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $isProjectSelectorPresented, arrowEdge: .top) {
                        ProjectSelectorView(viewModel: viewModel, isPresented: $isProjectSelectorPresented)
                            .frame(width: 400, height: 500)
                    }

                    // 设置按钮
                    Button(action: {
                        NotificationCenter.postOpenSettings()
                    }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14))
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(Color.black.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // 项目选择提示
                if !viewModel.isProjectSelected {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)

                        Text("请先选择一个项目才能开始对话")
                            .font(DesignTokens.Typography.caption1)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                        Spacer()

                        Button(action: {
                            isProjectSelectorPresented = true
                        }) {
                            Text("选择项目")
                                .font(DesignTokens.Typography.caption1)
                                .fontWeight(.medium)
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.05))
                }
            }
            .background(DesignTokens.Material.glassThick)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.black.opacity(0.05)),
                alignment: .bottom
            )

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
                // 快捷短语区域
                if showQuickPhrases && viewModel.isProjectSelected {
                    QuickPhrasesView { prompt in
                        viewModel.currentInput = prompt
                        isInputFocused = true
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                GlassDivider()

                HStack(alignment: .bottom) {
                    // 供应商选择器
                    VStack(spacing: 0) {
                        Spacer()

                        // 快捷短语显示切换按钮
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showQuickPhrases.toggle()
                            }
                        }) {
                            Image(systemName: showQuickPhrases ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10))
                                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .help(showQuickPhrases ? "隐藏快捷短语" : "显示快捷短语")
                        .padding(.bottom, 4)

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

                    ZStack {
                        if viewModel.isProcessing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            GlassButton(systemImage: "paperplane.fill", style: .primary) {
                                viewModel.sendMessage()
                            }
                            .disabled(viewModel.currentInput.isEmpty || !viewModel.isProjectSelected)
                        }
                    }
                    .frame(width: 44, height: 44)
                }
                .padding(12)
                .background(DesignTokens.Material.glass)
            }
            .frame(height: showQuickPhrases ? 110 : 56)
            .animation(.easeInOut(duration: 0.2), value: showQuickPhrases)
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
        .inRootView()
        .withDebugBar()
}
