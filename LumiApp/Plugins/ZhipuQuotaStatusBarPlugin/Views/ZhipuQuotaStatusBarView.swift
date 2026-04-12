import MagicKit
import SwiftUI
import Foundation
import os

/// 智谱 GLM 配额状态栏视图
struct ZhipuQuotaStatusBarView: View, SuperLog {
    nonisolated static let emoji = "📊"
    nonisolated static let verbose = false

    @EnvironmentObject private var llmVM: LLMVM
    @State private var quotaStatus: ZhipuQuotaStatus = .loading
    @State private var lastUpdateTime: Date?
    @State private var timer: Timer?

    // 缓存策略：5 分钟内不重复请求
    private let cacheTTL: TimeInterval = 300 // 5 分钟
    private var shouldRefresh: Bool {
        guard let lastUpdate = lastUpdateTime else { return true }
        return Date().timeIntervalSince(lastUpdate) > cacheTTL
    }

    /// 判断是否应该显示（仅在 Zhipu 供应商激活时）
    private var shouldShow: Bool {
        llmVM.selectedProviderId == "zhipu"
    }

    var body: some View {
        Group {
            if shouldShow {
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
        }
        .onAppear {
            if shouldShow {
                refreshQuota()
                startTimer()
            }
        }
        .onChange(of: llmVM.selectedProviderId) { _, newId in
            // 监听供应商切换
            if newId == "zhipu" {
                // 切换到 Zhipu，刷新配额并启动定时器
                refreshQuota()
                startTimer()
            } else {
                // 切换到其他供应商，停止定时器
                stopTimer()
            }
        }
        .onDisappear {
            stopTimer()
        }
    }

    /// 加载视图
    private var loadingView: some View {
        StatusBarHoverContainer(
            detailView: ZhipuQuotaDetailView(status: quotaStatus, onRefresh: {
                refreshQuota()
            }),
            id: "zhipu-quota-status"
        ) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 10))

                Text("加载中...")
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    /// 成功视图
    private func successView(_ data: ZhipuQuotaData) -> some View {
        StatusBarHoverContainer(
            detailView: ZhipuQuotaDetailView(status: quotaStatus, onRefresh: {
                refreshQuota()
            }),
            id: "zhipu-quota-status"
        ) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 10))

                Text(data.statusText)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    /// 错误视图
    private func errorView(_ message: String) -> some View {
        StatusBarHoverContainer(
            detailView: ZhipuQuotaDetailView(status: quotaStatus, onRefresh: {
                refreshQuota()
            }),
            id: "zhipu-quota-status"
        ) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)

                Text(message)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            // 仅在当前使用 Zhipu 供应商时刷新
            guard shouldShow else { return }

            if shouldRefresh {
                refreshQuota()
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
            let result = await ZhipuQuotaService.fetchQuota()
            await MainActor.run {
                quotaStatus = result.status
                lastUpdateTime = Date()

                if case .success(let data) = result.status {
                    ZhipuQuotaStatusBarPlugin.logger.info("\(Self.t)配额刷新成功: \(data.statusText)")
                } else {
                    ZhipuQuotaStatusBarPlugin.logger.warning("\(Self.t)配额刷新失败")
                }
            }
        }
    }
}
