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
                        
                        // 配额进度条
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("剩余配额:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(data.remains) / \(data.totalCount)")
                                    .fontWeight(.medium)
                            }
                            
                            ProgressView(value: Double(data.remains), total: Double(data.totalCount))
                                .progressViewStyle(.linear)
                                .tint(data.remains > 0 ? .green : .red)
                        }
                        
                        // 使用百分比
                        HStack {
                            Text("使用率:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.1f%%", 100 - data.remainingPercentage))
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
