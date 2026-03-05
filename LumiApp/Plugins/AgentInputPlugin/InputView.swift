import AppKit
import MagicKit
import OSLog
import SwiftUI

/// Agent 输入包装视图 - 管理输入区域所需的状态
/// 封装 InputAreaView 并提供模型选择器 popover
struct InputView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "💬"
    /// 是否输出详细日志
    nonisolated static let verbose = false

    /// 输入框是否处于聚焦状态
    @State private var isInputFocused: Bool = false

    /// 模型选择器是否显示
    @State private var isModelSelectorPresented = false

    var body: some View {
        InputAreaView(
            isInputFocused: $isInputFocused,
            isModelSelectorPresented: $isModelSelectorPresented
        )
        .onAppear(perform: onAppear)
        .overlay {
            if let request = AgentProvider.shared.pendingPermissionRequest {
                PermissionRequestView(
                    request: request,
                    onAllow: {
                        AgentProvider.shared.respondToPermissionRequest(allowed: true)
                    },
                    onDeny: {
                        AgentProvider.shared.respondToPermissionRequest(allowed: false)
                    }
                )
            }
        }
        .popover(isPresented: $isModelSelectorPresented, arrowEdge: .bottom) {
            ModelSelectorView()
        }
    }
}

// MARK: - Actions

// MARK: - Event Handler

extension InputView {
    func onAppear() {
        isInputFocused = true
    }
}

// MARK: - Preview

#Preview("App - Small Screen") {
    InputView()
        .frame(width: 800, height: 600)
        .inRootView()
}

#Preview("App - Big Screen") {
    InputView()
        .frame(width: 1200, height: 800)
        .inRootView()
}
