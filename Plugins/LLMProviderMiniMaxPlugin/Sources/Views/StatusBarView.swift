import Foundation
import KernelLumi
import LumiUI
import SwiftUI

/// MiniMax Token Plan 状态栏视图
struct StatusBarView: View {
    let network: (any NetworkProviding)?
    @State private var tokenPlanStatus: TokenPlanStatus = .loading
    @State private var lastUpdateTime: Date?
    @State private var refreshTimer: Timer?
    
    /// 缓存策略：5 分钟内不重复请求
    private let cacheTTL: TimeInterval = 300 // 5 分钟
    
    private var shouldRefresh: Bool {
        guard let lastUpdate = lastUpdateTime else { return true }
        return Date().timeIntervalSince(lastUpdate) > cacheTTL
    }
    
    var body: some View {
        Group {
            switch tokenPlanStatus {
            case .loading:
                loadingView
            case .success(let data):
                successView(data)
            case .authError:
                errorView("认证失败")
            case .unavailable:
                errorView("配额不可用")
            }
        }
        .onAppear {
            refreshTokenPlan()
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    /// 加载视图
    private var loadingView: some View {
        StatusBarHoverContainer(
            detailView: TokenPlanDetailView(status: tokenPlanStatus, onRefresh: {
                refreshTokenPlan()
            }),
            id: "minimax-token-plan-status"
        ) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.appMicroEmphasized)
                
                Text("加载中...")
                    .font(.appMicro)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
    
    /// 成功视图
    private func successView(_ plans: [TokenPlanData]) -> some View {
        StatusBarHoverContainer(
            detailView: TokenPlanDetailView(status: tokenPlanStatus, onRefresh: {
                refreshTokenPlan()
            }),
            id: "minimax-token-plan-status"
        ) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.appMicroEmphasized)
                
                Text(TokenPlanData.statusBarText(from: plans))
                    .font(.appMicro)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
    
    /// 错误视图
    private func errorView(_ message: String) -> some View {
        StatusBarHoverContainer(
            detailView: TokenPlanDetailView(status: tokenPlanStatus, onRefresh: {
                refreshTokenPlan()
            }),
            id: "minimax-token-plan-status"
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
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                if shouldRefresh {
                    refreshTokenPlan()
                }
            }
        }
    }
    
    private func stopTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Data Fetching
    
    private func refreshTokenPlan() {
        Task {
            let status = await TokenPlanService.fetchTokenPlan(network: network)
            await MainActor.run {
                tokenPlanStatus = status
                lastUpdateTime = Date()
            }
        }
    }
}
