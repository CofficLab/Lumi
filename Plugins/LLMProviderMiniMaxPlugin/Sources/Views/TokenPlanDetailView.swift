import Foundation
import KernelLumi
import LumiUI
import SwiftUI

// MARK: - Model Display Info

/// 模型显示配置
enum ModelDisplayConfig {
    case general
    case video
    case unknown
    
    var displayName: String {
        switch self {
        case .general: return "常规模型"
        case .video: return "视频模型"
        case .unknown: return "未知模型"
        }
    }
    
    var intervalTitle: String {
        switch self {
        case .general: return "5 小时窗口"
        case .video: return "5 小时窗口"
        case .unknown: return "当前时段"
        }
    }
    
    var intervalDescription: String {
        switch self {
        case .general: return "常规模型的 5 小时调用限额"
        case .video: return "视频模型的 5 小时调用限额"
        case .unknown: return ""
        }
    }
    
    static func from(_ modelName: String) -> ModelDisplayConfig {
        switch modelName.lowercased() {
        case "general": return .general
        case "video": return .video
        default: return .unknown
        }
    }
}

/// MiniMax Token Plan 详情视图
struct TokenPlanDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let status: TokenPlanStatus
    let onRefresh: () -> Void
    
    var body: some View {
        StatusBarPopoverScaffold(
            title: LumiPluginLocalization.string("MiniMax Token Plan", bundle: .module),
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
                    Text(LumiPluginLocalization.string("认证失败，请检查 API Key", bundle: .module))
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
    private func detailContent(_ plans: [TokenPlanData]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(plans.enumerated()), id: \.offset) { index, data in
                if index > 0 {
                    Divider()
                        .padding(.vertical, 8)
                }
                modelSection(data)
            }
        }
    }
    
    @ViewBuilder
    private func modelSection(_ data: TokenPlanData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 模型名称
            HStack {
                Text("模型:")
                    .foregroundColor(theme.textSecondary)
                Text(ModelDisplayConfig.from(data.modelName).displayName)
                    .fontWeight(.medium)
            }
            
            // MARK: - 5 小时窗口
            sectionHeader(
                ModelDisplayConfig.from(data.modelName).intervalTitle,
                description: ModelDisplayConfig.from(data.modelName).intervalDescription
            )
            
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
                .padding(.vertical, 4)
            
            // MARK: - 本周
            sectionHeader("本周配额", description: "本周累计调用限额")
            
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
    
    private func sectionHeader(_ title: String, description: String = "") -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            if !description.isEmpty {
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
            }
        }
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
            if total == 0 {
                Text("无限")
                    .fontWeight(.medium)
                    .foregroundColor(theme.success)
            } else {
                Text("\(usage) / \(total)")
                    .fontWeight(.medium)
            }
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
