import LumiUI
import SwiftUI
import Foundation
import LumiKernel

/// 智谱 GLM 配额状态栏视图
///
/// 显示/隐藏由 ``ZhipuPlugin`` 在插件层根据 ``LumiPluginContext.activeProviderID`` 控制，
/// 此视图被创建时即可假定当前活跃供应商为智谱。
struct StatusBarView: View {
    @State private var quotaStatus: QuotaStatus = .loading
    @State private var lastUpdateTime: Date?
    @State private var timer: Timer?

    // 缓存策略：5 分钟内不重复请求
    private let cacheTTL: TimeInterval = 300 // 5 分钟
    private var shouldRefresh: Bool {
        guard let lastUpdate = lastUpdateTime else { return true }
        return Date().timeIntervalSince(lastUpdate) > cacheTTL
    }

    var body: some View {
        Group {
            switch quotaStatus {
            case .loading:
                loadingView
            case .success(let data):
                successView(data)
            case .authError:
                errorView("认证过期")
            case .unavailable:
                errorView("配额不可用")
            }
        }
        .onAppear {
            refreshQuota()
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    /// 加载视图
    private var loadingView: some View {
        StatusBarHoverContainer(
            detailView: QuotaDetailView(status: quotaStatus, onRefresh: {
                refreshQuota()
            }),
            id: "zhipu-quota-status"
        ) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.appMicroEmphasized)

                Text(LumiPluginLocalization.string("加载中...", bundle: .module))
                    .font(.appMicro)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    /// 成功视图
    private func successView(_ data: QuotaData) -> some View {
        StatusBarHoverContainer(
            detailView: QuotaDetailView(status: quotaStatus, onRefresh: {
                refreshQuota()
            }),
            id: "zhipu-quota-status"
        ) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.appMicroEmphasized)

                Text(data.statusText)
                    .font(.appMicro)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    /// 错误视图
    private func errorView(_ message: String) -> some View {
        StatusBarHoverContainer(
            detailView: QuotaDetailView(status: quotaStatus, onRefresh: {
                refreshQuota()
            }),
            id: "zhipu-quota-status"
        ) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.appMicroEmphasized)

                Text(message)
                    .font(.appMicro)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                if shouldRefresh {
                    refreshQuota()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Data Fetching

    private func refreshQuota() {
        Task {
            let status = await QuotaService.fetchQuota()
            await MainActor.run {
                quotaStatus = status
                lastUpdateTime = Date()
            }
        }
    }
}
