import SwiftUI

/// DevAssistant 输入包装视图 - 管理输入区域所需的状态
struct DevAssistantInputView: View {
    @EnvironmentObject var agentProvider: AgentProvider
    @State private var isInputFocused: Bool = false
    @State private var isModelSelectorPresented = false

    var body: some View {
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
        .onAppear {
            isInputFocused = true
        }
        .overlay {
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
        .popover(isPresented: $isModelSelectorPresented, arrowEdge: .bottom) {
            ModelSelectorView()
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
                agentProvider.handleImageUpload(url: url)
            }
        }
    }
}
