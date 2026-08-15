import Foundation
import KernelLumi
import LumiUI
import SwiftUI

/// OpenCode Go 配额状态栏视图
struct OpenCodeGoStatusBarView: View {
    let kernel: KernelLumi
    @State private var status: OpenCodeGoStatus = .loading
    @State private var lastUpdateTime: Date?
    @State private var refreshTimer: Timer?

    /// 缓存策略：2 分钟内不重复请求
    private let cacheTTL: TimeInterval = 120

    private var shouldRefresh: Bool {
        guard let lastUpdate = lastUpdateTime else { return true }
        return Date().timeIntervalSince(lastUpdate) > cacheTTL
    }

    var body: some View {
        Group {
            switch status {
            case .loading:
                loadingView
            case .success(let state):
                successView(state)
            case .unavailable(let message):
                errorView(message)
            }
        }
        .onAppear {
            refreshState()
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    /// 加载视图
    private var loadingView: some View {
        StatusBarHoverContainer(
            detailView: OpenCodeGoDetailView(status: status, onRefresh: {
                refreshState()
            }),
            id: "opencodego-status"
        ) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.appMicroEmphasized)

                Text("加载中...")
                    .font(.appMicro)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    /// 成功视图
    private func successView(_ state: OpenCodeGoState) -> some View {
        StatusBarHoverContainer(
            detailView: OpenCodeGoDetailView(status: status, onRefresh: {
                refreshState()
            }),
            id: "opencodego-status"
        ) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.appMicroEmphasized)

                // 优先显示服务端配额（如果有）
                if let serverText = state.serverStatusBarText {
                    Text(serverText)
                        .font(.appMicro)
                } else {
                    Text(state.statusBarText)
                        .font(.appMicro)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    /// 错误视图
    private func errorView(_ message: String) -> some View {
        StatusBarHoverContainer(
            detailView: OpenCodeGoDetailView(status: status, onRefresh: {
                refreshState()
            }),
            id: "opencodego-status"
        ) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.slash.fill")
                    .font(.appMicroEmphasized)

                Text("未连接")
                    .font(.appMicro)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                if shouldRefresh {
                    refreshState()
                }
            }
        }
    }

    private func stopTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Data Fetching

    private func refreshState() {
        Task {
            let newStatus = await OpenCodeGoService.fetchState(network: kernel.network)
            await MainActor.run {
                status = newStatus
                lastUpdateTime = Date()
            }
        }
    }
}
