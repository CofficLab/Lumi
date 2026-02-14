import SwiftUI

/// Dev Assistant 主视图 - 聊天界面
struct DevAssistantView: View {
    @StateObject private var viewModel = DevAssistantViewModel()
    @State private var isInputFocused: Bool = false
    @State private var isModelSelectorPresented = false
    @State private var isProjectSelectorPresented = false

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
                    
                    // 风险自动批准开关
                    HStack(spacing: 6) {
                        Text("Auto")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        
                        Toggle("", isOn: $viewModel.autoApproveRisk)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(6)
                    .help("Automatically approve high-risk commands")

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

                // 输入框容器
                VStack(spacing: 0) {
                    MacEditorView(
                        text: $viewModel.currentInput,
                        onSubmit: {
                            viewModel.sendMessage()
                        },
                        isFocused: $isInputFocused
                    )
                    .frame(height: 32)
                    .padding(.horizontal, 4)
                    .padding(.top, 8)
                    
                    // 工具栏
                    HStack(alignment: .center, spacing: 8) {
                        // 模型选择器
                        Button(action: {
                            isModelSelectorPresented = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "globe")
                                    .font(.system(size: 14))
                                Text(viewModel.currentModel)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $isModelSelectorPresented, arrowEdge: .bottom) {
                            ModelSelectorView(viewModel: viewModel)
                        }
                        
                        Spacer()
                        
                        // 发送按钮
                        if viewModel.isProcessing {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 28, height: 28)
                        } else {
                            Button(action: {
                                viewModel.sendMessage()
                            }) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(viewModel.currentInput.isEmpty || !viewModel.isProjectSelected ? Color.gray.opacity(0.5) : Color.accentColor)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.currentInput.isEmpty || !viewModel.isProjectSelected)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                .padding(16)
            }
            .background(DesignTokens.Material.glass)
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
