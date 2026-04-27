import SwiftUI

/// Code Server 主视图
///
/// 负责状态管理和启动逻辑，按需展示 WebView 或状态视图。
struct CodeServerView: View {
    @StateObject private var manager = CodeServerManager.shared
    @EnvironmentObject private var projectVM: ProjectVM
    @State private var isLoading = true
    @State private var serverReady = false
    @State private var didAttemptStart = false

    /// 当前加载的项目路径（用于切换项目时更新 WebView URL）
    @State private var currentFolder: String = ""

    var body: some View {
        ZStack {
            if serverReady {
                CodeServerWebView(
                    url: buildCodeServerURL(),
                    injectCSS: false,
                    reloadTrigger: manager.shouldReloadWebView
                )
            } else {
                CodeServerStatusView(
                    isRunning: manager.isRunning,
                    errorMessage: manager.errorMessage,
                    isLoading: isLoading,
                    onRetry: {
                        Task { @MainActor in
                            await retryConnection()
                        }
                    }
                )
            }
        }
        .onAppear {
            verifyServerAndStartIfNeeded()
        }
        .onChange(of: projectVM.currentProjectPath) { _, newProjectPath in
            // 项目切换后，在现有 WebView 中导航到新项目
            if manager.isRunning, !newProjectPath.isEmpty {
                currentFolder = newProjectPath
            }
        }
        .frame(minWidth: 800)
    }

    // MARK: - Private

    /// 构建 code-server URL，包含当前项目路径参数
    private func buildCodeServerURL() -> URL {
        guard !currentFolder.isEmpty else {
            return URL(string: "http://127.0.0.1:\(manager.port)")!
        }
        // code-server 支持 ?folder= 参数打开指定目录
        var components = URLComponents(string: "http://127.0.0.1:\(manager.port)")!
        components.queryItems = [URLQueryItem(name: "folder", value: currentFolder)]
        return components.url!
    }

    /// 视图出现时先做健康检查，避免状态残留导致直接显示空白 WebView
    private func verifyServerAndStartIfNeeded() {
        Task { @MainActor in
            if !projectVM.currentProjectPath.isEmpty {
                currentFolder = projectVM.currentProjectPath
            }

            if await manager.isServerReachable() {
                manager.syncDefaultSettingsAndReloadWebView()
                serverReady = true
                isLoading = false
                didAttemptStart = true
                return
            }

            // 如果进程状态和实际可达性不一致，优先重置状态并走统一启动流程
            serverReady = false
            didAttemptStart = false
            startServerIfNeeded()
        }
    }

    private func startServerIfNeeded() {
        guard !didAttemptStart else { return }
        didAttemptStart = true

        Task { @MainActor in
            isLoading = true

            // 先检查是否已经可访问
            if await manager.isServerReachable() {
                manager.syncDefaultSettingsAndReloadWebView()
                serverReady = true
                isLoading = false
                return
            }

            // 未运行则启动，自动打开当前项目
            if !manager.isRunning {
                let projectPath = projectVM.currentProjectPath.isEmpty ? nil : projectVM.currentProjectPath
                if let path = projectPath {
                    currentFolder = path
                }
                manager.start(port: 8080, openPath: projectPath)
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

    /// 重试连接（用户点击重试按钮时调用）
    private func retryConnection() async {
        // 重置状态
        didAttemptStart = false
        serverReady = false
        isLoading = true
        manager.errorMessage = nil

        // 先检查是否已经可访问（可能用户已安装）
        if await manager.isServerReachable() {
            manager.syncDefaultSettingsAndReloadWebView()
            serverReady = true
            isLoading = false
            return
        }

        // 停止旧的进程（如果存在）
        manager.stop()

        // 重新启动
        let projectPath = projectVM.currentProjectPath.isEmpty ? nil : projectVM.currentProjectPath
        manager.start(port: 8080, openPath: projectPath)

        // 轮询等待服务就绪（最多 15 秒）
        var attempts = 0
        let maxAttempts = 30
        while attempts < maxAttempts {
            try? await Task.sleep(for: .milliseconds(500))
            if await manager.isServerReachable() {
                serverReady = true
                isLoading = false
                return
            }
            attempts += 1
        }

        // 超时
        isLoading = false
        if manager.errorMessage == nil && !manager.isRunning {
            manager.errorMessage = "code-server 启动超时，请确认已安装"
        }
    }
}
