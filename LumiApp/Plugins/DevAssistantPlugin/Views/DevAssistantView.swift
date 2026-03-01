import SwiftUI
import UniformTypeIdentifiers

/// Dev Assistant 主视图 - 聊天界面
struct DevAssistantView: View {
    @StateObject private var viewModel = AssistantViewModel()
    @State private var isInputFocused: Bool = false
    @State private var isModelSelectorPresented = false
    @State private var isProjectSelectorPresented = false
    @State private var isMCPSettingsPresented = false

    var body: some View {
        VStack(spacing: 8) {
            // MARK: - Header

            ChatHeaderView(
                viewModel: viewModel,
                isProjectSelectorPresented: $isProjectSelectorPresented,
                isMCPSettingsPresented: $isMCPSettingsPresented
            )

            // MARK: - Depth Warning Banner

            if let warning = viewModel.depthWarning {
                DepthWarningBanner(
                    warning: warning,
                    onDismiss: {
                        withAnimation {
                            viewModel.depthWarning = nil
                        }
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // MARK: - Chat History

            ChatMessagesView(viewModel: viewModel)

            // MARK: - Input Area

            InputAreaView(
                viewModel: viewModel,
                isInputFocused: $isInputFocused,
                isModelSelectorPresented: $isModelSelectorPresented,
                onSendMessage: {
                    viewModel.sendMessage()
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
                            viewModel.handleImageUpload(url: url)
                        }
                        return true
                    }
                    return false
                }
            )
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
        .popover(isPresented: $isMCPSettingsPresented, arrowEdge: .top) {
            MCPSettingsView()
        }
        .popover(isPresented: $isProjectSelectorPresented, arrowEdge: .top) {
            ProjectSelectorView(viewModel: viewModel, isPresented: $isProjectSelectorPresented)
                .frame(width: 400, height: 500)
        }
        .popover(isPresented: $isModelSelectorPresented, arrowEdge: .bottom) {
            ModelSelectorView(viewModel: viewModel)
        }
    }

    private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]

        panel.begin { response in
            if response == .OK, let url = panel.url {
                viewModel.handleImageUpload(url: url)
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
