import SwiftUI
import OSLog
import MagicKit

// MARK: - Heartbeat Indicator

/// 心跳动画指示器
/// 在处理状态时显示绿色脉冲圆点，提供视觉反馈
struct HeartbeatIndicator: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "💓"
    /// 是否启用详细日志
    nonisolated static let verbose = false

    /// 智能体提供者
    @EnvironmentObject var agentProvider: AgentProvider
    /// 处理状态 ViewModel
    @EnvironmentObject var processingStateViewModel: ProcessingStateViewModel
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: 6, height: 6)
            .scaleEffect(pulseScale)
            .opacity(isAnimating ? 1.0 : 0.4)
            .onAppear {
                startAnimation()
            }
            .onChange(of: processingStateViewModel.lastHeartbeatTime) { _, _ in
                triggerPulse()
            }
            .onChange(of: processingStateViewModel.isProcessing) { _, isProcessing in
                if isProcessing {
                    startAnimation()
                } else {
                    stopAnimation()
                }
            }
    }

    // MARK: - Animation Methods

    /// 启动基础呼吸动画
    private func startAnimation() {
        guard processingStateViewModel.isProcessing else { return }

        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            isAnimating = true
        }
    }

    /// 停止动画
    private func stopAnimation() {
        withAnimation(.easeOut(duration: 0.2)) {
            isAnimating = false
            pulseScale = 1.0
        }
    }

    /// 触发心跳脉冲效果
    private func triggerPulse() {
        withAnimation(.easeOut(duration: 0.3)) {
            pulseScale = 1.8
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeIn(duration: 0.3)) {
                pulseScale = 1.0
            }
        }
    }
}
