import SwiftUI
import UniformTypeIdentifiers

/// Dev Assistant 主视图 - 聊天界面
struct DevAssistantView: View {
    @EnvironmentObject var agentProvider: AgentProvider

    @State private var isInputFocused: Bool = false
    @State private var isModelSelectorPresented = false
    @State private var isProjectSelectorPresented = false
    @State private var isMCPSettingsPresented = false

    var body: some View {
        VStack(spacing: 8) {
            // MARK: - Header

            ChatHeaderView(
                isProjectSelectorPresented: $isProjectSelectorPresented,
                isMCPSettingsPresented: $isMCPSettingsPresented
            )

            // MARK: - Depth Warning Banner

            if let warning = agentProvider.depthWarning {
                DepthWarningBanner(
                    warning: warning,
                    onDismiss: {
                        withAnimation {
                            agentProvider.setDepthWarning(nil)
                        }
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // MARK: - Chat History

            ChatMessagesView()

            // MARK: - Input Area

            InputAreaView(
                isInputFocused: $isInputFocused,
                isModelSelectorPresented: $isModelSelectorPresented,
                onSendMessage: {
                    agentProvider.sendMessage()
                },
                onImageUpload: {
                    selectImage()
                },
                onDropImage: { urls in
                    let imageURLs = urls.filter { url in
                        let ext = url.pathExtension.lowercased()
                        return ["png", "jpg", "jpeg", "gif", "webp"].contains(ext)
                    }

                    if !imageURLs.isEmpty {
                        for url in imageURLs {
                            agentProvider.handleImageUpload(url: url)
                        }
                        return true
                    }
                    return false
                },
                onStopGenerating: {
                    agentProvider.cancelCurrentTask()
                }
            )
        }
        .onAppear {
            isInputFocused = true
        }
        .overlay {
            // MARK: - Permission Request Overlay

            if let request = agentProvider.pendingPermissionRequest {
                PermissionRequestView(
                    request: request,
                    onAllow: {
                        agentProvider.respondToPermissionRequest(allowed: true)
                    },
                    onDeny: {
                        agentProvider.respondToPermissionRequest(allowed: false)
                    }
                )
            }
        }
        .popover(isPresented: $isMCPSettingsPresented, arrowEdge: .top) {
            MCPSettingsView()
        }
        .popover(isPresented: $isProjectSelectorPresented, arrowEdge: .top) {
            ProjectSelectorView(isPresented: $isProjectSelectorPresented)
                .frame(width: 400, height: 500)
        }
        .popover(isPresented: $isModelSelectorPresented, arrowEdge: .bottom) {
            ModelSelectorView()
        }
    }

    // MARK: - Methods

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
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(DevAssistantPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
