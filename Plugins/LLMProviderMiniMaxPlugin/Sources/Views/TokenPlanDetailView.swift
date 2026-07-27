import Foundation
import LumiKernel
import LumiUI
import SwiftUI

/// MiniMax Token Plan 详情视图
struct TokenPlanDetailView: View {
    let status: TokenPlanStatus
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("MiniMax Token Plan")
                    .font(.headline)
                Spacer()
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            
            // 内容
            Group {
                switch status {
                case .loading:
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("加载中...")
                            .foregroundColor(.secondary)
                    }
                    
                case .success(let data):
                    VStack(alignment: .leading, spacing: 8) {
                        // 模型名称
                        HStack {
                            Text("模型:")
                                .foregroundColor(.secondary)
                            Text(data.modelName)
                                .fontWeight(.medium)
                        }
                        
                        // 当前时段剩余百分比
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("当前时段剩余:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(data.remainingPercent)%")
                                    .fontWeight(.medium)
                            }
                            
                            ProgressView(value: Double(data.remainingPercent), total: 100)
                                .progressViewStyle(.linear)
                                .tint(data.remainingPercent > 20 ? .green : .red)
                        }
                        
                        // 本周剩余百分比
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("本周剩余:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(data.weeklyRemainingPercent)%")
                                    .fontWeight(.medium)
                            }
                            
                            ProgressView(value: Double(data.weeklyRemainingPercent), total: 100)
                                .progressViewStyle(.linear)
                                .tint(data.weeklyRemainingPercent > 20 ? .green : .red)
                        }
                        
                        // 当前时段调用次数
                        HStack {
                            Text("调用次数:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(data.intervalUsage) / \(data.intervalTotal)")
                                .fontWeight(.medium)
                        }
                    }
                    
                case .authError:
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("认证失败，请检查 API Key")
                            .foregroundColor(.red)
                    }
                    
                case .unavailable:
                    HStack {
                        Image(systemName: "xmark.octagon.fill")
                            .foregroundColor(.orange)
                        Text("无法获取配额信息")
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 280)
    }
}
