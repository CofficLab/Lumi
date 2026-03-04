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
                isModelSelectorPresented: $isModelSelectorPresented
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
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(DevAssistantPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
