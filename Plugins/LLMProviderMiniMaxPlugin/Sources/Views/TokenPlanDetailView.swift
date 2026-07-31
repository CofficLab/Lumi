import Foundation
import LumiKernel
import LumiUI
import SwiftUI

/// MiniMax Token Plan 详情视图
struct TokenPlanDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let status: TokenPlanStatus
    let onRefresh: () -> Void
    
    var body: some View {
        StatusBarPopoverScaffold(
            title: "MiniMax Token Plan",
            systemImage: "chart.bar.fill"
        ) {
            AppIconButton(systemImage: "arrow.clockwise") {
                onRefresh()
            }
        } content: {
                switch status {
                case .loading:
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("加载中...")
                            .foregroundColor(theme.textSecondary)
                    }
                    
                case .success(let data):
                    detailContent(data)
                    
                case .authError:
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(theme.error)
                        Text("认证失败，请检查 API Key")
                            .foregroundColor(theme.error)
                    }
                    
                case .unavailable:
                    HStack {
                        Image(systemName: "xmark.octagon.fill")
                            .foregroundColor(theme.warning)
                        Text("无法获取配额信息")
                            .foregroundColor(theme.warning)
                    }
                }
        }
    }
    
    // MARK: - Detail Content
    
    @ViewBuilder
    private func detailContent(_ data: TokenPlanData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 模型名称
            HStack {
                Text("模型:")
                    .foregroundColor(theme.textSecondary)
                Text(data.modelName)
                    .fontWeight(.medium)
            }
            
            Divider()
            
            // MARK: - 当前时段
            sectionHeader("当前时段")
            
            // 剩余百分比
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("剩余:")
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                    Text("\(data.remainingPercent)%")
                        .fontWeight(.medium)
                }
                ProgressView(value: Double(data.remainingPercent), total: 100)
                    .progressViewStyle(.linear)
                    .tint(data.remainingPercent > 20 ? theme.success : theme.error)
            }
            
            // 状态
            statusRow(label: "状态:", value: data.intervalStatusLabel, status: data.intervalStatus)
            
            // 调用次数
            countRow(label: "调用次数:", usage: data.intervalUsage, total: data.intervalTotal)
            
            // 时间段
            timeRow(label: "时间段:", value: data.intervalTimeRange)
            
            // 重置时间
            timeRow(label: "重置时间:", value: data.remainsTimeText)
            
            Divider()
            
            // MARK: - 本周
            sectionHeader("本周配额")
            
            // 剩余百分比
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("剩余:")
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                    Text("\(data.weeklyRemainingPercent)%")
                        .fontWeight(.medium)
                }
                ProgressView(value: Double(data.weeklyRemainingPercent), total: 100)
                    .progressViewStyle(.linear)
                    .tint(data.weeklyRemainingPercent > 20 ? theme.success : theme.error)
            }
            
            // 状态
            statusRow(label: "状态:", value: data.weeklyStatusLabel, status: data.weeklyStatus)
            
            // 调用次数
            countRow(label: "调用次数:", usage: data.weeklyUsage, total: data.weeklyTotal)
            
            // 时间段
            timeRow(label: "时间段:", value: data.weeklyTimeRange)
            
            // 重置时间
            timeRow(label: "重置时间:", value: data.weeklyRemainsTimeText)
        }
    }
    
    // MARK: - Row Builders
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(theme.textPrimary)
    }
    
    private func statusRow(label: String, value: String, status: Int) -> some View {
        HStack {
            Text(label)
                .foregroundColor(theme.textSecondary)
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(status == 1 ? theme.success : theme.error)
                    .frame(width: 6, height: 6)
                Text(value)
                    .fontWeight(.medium)
                    .foregroundColor(status == 1 ? theme.success : theme.error)
            }
        }
    }
    
    private func countRow(label: String, usage: Int, total: Int) -> some View {
        HStack {
            Text(label)
                .foregroundColor(theme.textSecondary)
            Spacer()
            Text("\(usage) / \(total)")
                .fontWeight(.medium)
        }
    }
    
    private func timeRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(theme.textSecondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .font(.system(size: 11))
        }
    }
}
