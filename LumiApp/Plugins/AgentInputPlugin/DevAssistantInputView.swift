import AppKit
import MagicKit
import OSLog
import SwiftUI

/// DevAssistant 输入包装视图 - 管理输入区域所需的状态
/// 封装 InputAreaView 并提供图片选择、模型选择等功能
struct DevAssistantInputView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "💬"
    /// 是否输出详细日志
    nonisolated static let verbose = false

    /// 智能体提供者
    @EnvironmentObject var agentProvider: AgentProvider

    /// 输入框是否处于聚焦状态
    @State private var isInputFocused: Bool = false

    /// 模型选择器是否显示
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

    // MARK: - Action

    /// 选择图片文件
    /// 使用 NSOpenPanel 选择图片并上传到 Agent
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

#Preview("App - Small Screen") {
    DevAssistantInputView()
        .frame(width: 800, height: 600)
        .inRootView()
}

#Preview("App - Big Screen") {
    DevAssistantInputView()
        .frame(width: 1200, height: 800)
        .inRootView()
}
