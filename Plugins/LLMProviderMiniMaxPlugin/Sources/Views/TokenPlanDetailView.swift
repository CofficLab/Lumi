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
                    VStack(alignment: .leading, spacing: 8) {
                        // 模型名称
                        HStack {
                            Text("模型:")
                                .foregroundColor(theme.textSecondary)
                            Text(data.modelName)
                                .fontWeight(.medium)
                        }
                        
                        // 当前时段剩余百分比
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("当前时段剩余:")
                                    .foregroundColor(theme.textSecondary)
                                Spacer()
                                Text("\(data.remainingPercent)%")
                                    .fontWeight(.medium)
                            }
                            
                            ProgressView(value: Double(data.remainingPercent), total: 100)
                                .progressViewStyle(.linear)
                                .tint(data.remainingPercent > 20 ? theme.success : theme.error)
                        }
                        
                        // 本周剩余百分比
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("本周剩余:")
                                    .foregroundColor(theme.textSecondary)
                                Spacer()
                                Text("\(data.weeklyRemainingPercent)%")
                                    .fontWeight(.medium)
                            }
                            
                            ProgressView(value: Double(data.weeklyRemainingPercent), total: 100)
                                .progressViewStyle(.linear)
                                .tint(data.weeklyRemainingPercent > 20 ? theme.success : theme.error)
                        }
                        
                        // 当前时段调用次数
                        HStack {
                            Text("调用次数:")
                                .foregroundColor(theme.textSecondary)
                            Spacer()
                            Text("\(data.intervalUsage) / \(data.intervalTotal)")
                                .fontWeight(.medium)
                        }
                    }
                    
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
}
