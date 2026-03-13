import Foundation
import SwiftUI
import OSLog
import MagicKit

/// 状态栏插件示例：显示当前状态信息
actor StatusBarPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    /// Log identifier
    nonisolated static let emoji = "📊"

    /// Whether to enable this plugin
    nonisolated static let enable = true

    /// Whether to enable verbose log output
    nonisolated static let verbose = false

    /// Plugin unique identifier
    static let id: String = "StatusBar"

    /// Plugin display name
    static let displayName: String = "状态栏"

    /// Plugin functional description
    static let description: String = "在 Agent 模式底部显示状态信息"

    /// Plugin icon name
    static let iconName: String = "info.circle.fill"

    /// Whether it is configurable
    static let isConfigurable: Bool = true

    /// Registration order
    static var order: Int { 90 }

    // MARK: - Instance

    /// Plugin instance label (used to identify unique instances)
    nonisolated var instanceLabel: String {
        Self.id
    }

    /// Plugin singleton instance
    static let shared = StatusBarPlugin()

    // MARK: - UI Contributions

    /// Add status bar view for Agent mode
    @MainActor func addStatusBarView() -> AnyView? {
        if Self.verbose {
            os_log("\(self.t) 提供 StatusBarView")
        }
        return AnyView(StatusBarView())
    }
}

// MARK: - Status Bar View

/// 状态栏视图
struct StatusBarView: View {
    @EnvironmentObject var agentProvider: AgentProvider
    
    var body: some View {
        HStack(spacing: 16) {
            // 左侧状态信息
            leftStatusItems
            
            Spacer()
            
            // 右侧状态信息
            rightStatusItems
        }
        .font(.system(size: 11))
    }
    
    // MARK: - Left Status Items
    
    private var leftStatusItems: some View {
        HStack(spacing: 16) {
            // 示例：显示连接状态
            statusItem(icon: "checkmark.circle.fill", text: "就绪", color: .green)
        }
    }
    
    // MARK: - Right Status Items
    
    private var rightStatusItems: some View {
        HStack(spacing: 16) {
            // 示例：显示模型信息
            statusItem(icon: "cpu.fill", text: "GPT-4", color: .secondary)
            
            // 示例：显示 token 使用
            statusItem(icon: "text.alignleft", text: "0 tokens", color: .secondary)
        }
    }
    
    // MARK: - Helper Views
    
    private func statusItem(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
        }
        .foregroundColor(color)
    }
}

// MARK: - Preview

#Preview {
    StatusBarView()
        .frame(height: 30)
}
