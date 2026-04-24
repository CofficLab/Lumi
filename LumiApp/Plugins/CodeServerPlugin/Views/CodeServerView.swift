import SwiftUI

/// Code Server 主视图
///
/// 负责状态管理和启动逻辑，按需展示 WebView 或状态视图。
struct CodeServerView: View {
    @StateObject private var manager = CodeServerManager.shared
    @State private var isLoading = true
    @State private var serverReady = false

    var body: some View {
        ZStack {
            if serverReady {
                CodeServerWebView(url: URL(string: "http://127.0.0.1:\(manager.port)")!)
            } else {
                CodeServerStatusView(
                    isRunning: manager.isRunning,
                    errorMessage: manager.errorMessage,
                    isLoading: isLoading
                )
                .onAppear {
                    startServerIfNeeded()
                }
            }
        }
    }

    // MARK: - Private

    private func startServerIfNeeded() {
        Task { @MainActor in
            isLoading = true

            // 先检查是否已经可访问
            if await manager.isServerReachable() {
                serverReady = true
                isLoading = false
                return
            }

            // 未运行则启动
            if !manager.isRunning {
                manager.start(port: 8080)
            }

            // 轮询等待服务就绪（最多 15 秒）
            var attempts = 0
            let maxAttempts = 30
            while attempts < maxAttempts {
                try? await Task.sleep(for: .milliseconds(500))
                if await manager.isServerReachable() {
                    await MainActor.run {
                        serverReady = true
                        isLoading = false
                    }
                    return
                }
                attempts += 1
            }

            // 超时
            await MainActor.run {
                isLoading = false
                if manager.errorMessage == nil && !manager.isRunning {
                    manager.errorMessage = "code-server 启动超时，请确认已安装"
                }
            }
        }
    }
}
