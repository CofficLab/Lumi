import Foundation
import MagicKit
import SwiftUI

/// 上下文同步覆盖层
/// 监听 projectVM 中当前项目路径的变化，当项目变化时向当前对话添加系统消息
struct ContextSyncOverlay<Content: View>: View, SuperLog {
    nonisolated static var verbose: Bool { false }
    nonisolated static var emoji: String { "🔄" }

    /// 项目 ViewModel
    @EnvironmentObject private var projectVM: ProjectVM
    
    /// 会话 ViewModel
    @EnvironmentObject private var conversationVM: ConversationVM
    
    /// 聊天历史 ViewModel
    @EnvironmentObject private var chatHistoryVM: ChatHistoryVM

    let content: Content

    /// 上一次的项目路径（用于检测变化）
    @State private var lastProjectPath: String = ""

    var body: some View {
        ZStack {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            handleOnAppear()
        }
        .onChange(of: projectVM.currentProjectPath) { oldPath, newPath in
            handleProjectPathChange(oldPath: oldPath, newPath: newPath)
        }
    }
}

// MARK: - Event Handler

extension ContextSyncOverlay {
    /// 视图出现时初始化
    private func handleOnAppear() {
        lastProjectPath = projectVM.currentProjectPath
        
        if Self.verbose {
            AppLogger.core.info("\(Self.t)📱 ContextSyncOverlay 已挂载，初始项目路径: \(lastProjectPath)")
        }
    }

    /// 处理项目路径变化
    private func handleProjectPathChange(oldPath: String, newPath: String) {
        // 如果路径没有变化，不处理
        guard oldPath != newPath else { return }
        
        // 如果新路径为空（清除项目），也不处理
        guard !newPath.isEmpty else {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)🗑️ 项目已清除，跳过系统消息")
            }
            return
        }

        // 添加系统消息
        Task { @MainActor in
            await addProjectChangeSystemMessage(
                oldPath: oldPath,
                newPath: newPath,
                projectName: projectVM.currentProjectName
            )
        }
    }

    /// 添加项目切换的系统消息
    private func addProjectChangeSystemMessage(oldPath: String, newPath: String, projectName: String) async {
        // 获取当前会话 ID
        guard let conversationId = conversationVM.selectedConversationId else {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)⚠️ 没有选中的会话，跳过添加系统消息")
            }
            return
        }

        // 构建消息内容
        let content: String
        if oldPath.isEmpty {
            content = "用户已选择项目：\(projectName)（路径：\(newPath)）"
        } else {
            content = "用户已切换项目：从 \(oldPath) 切换到 \(projectName)（路径：\(newPath)）"
        }

        // 创建系统消息
        let message = ChatMessage(
            role: .system,
            conversationId: conversationId,
            content: content
        )

        // 保存消息
        chatHistoryVM.saveMessage(message, toConversationId: conversationId)

        if Self.verbose {
            AppLogger.core.info("\(Self.t)✅ 已添加项目切换系统消息: \(content)")
        }
    }
}

// MARK: - Preview

#Preview("Context Sync Overlay") {
    ContextSyncOverlay(content: Text("Content"))
        .inRootView()
}
