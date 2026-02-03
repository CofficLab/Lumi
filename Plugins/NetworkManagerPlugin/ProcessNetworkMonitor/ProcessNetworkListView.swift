import SwiftUI

struct ProcessNetworkListView: View {
    @ObservedObject var viewModel: NetworkManagerViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                Text("进程监控")
                    .font(.headline)
                
                Spacer()
                
                Toggle("仅显示活跃", isOn: $viewModel.onlyActiveProcesses)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                
                TextField("搜索进程...", text: $viewModel.processSearchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))

            // 系统信息区块
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "power")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("运行时间")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(viewModel.systemUptime)
                        .font(.system(size: 12, weight: .medium))
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))

            // 表头
            HStack(spacing: 10) {
                Text("应用")
                    .frame(width: 200, alignment: .leading)
                
                Spacer()
                
                Text("下载")
                    .frame(width: 80, alignment: .trailing)
                
                Text("上传")
                    .frame(width: 80, alignment: .trailing)
                
                Text("总计")
                    .frame(width: 80, alignment: .trailing)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // 列表
            List {
                ForEach(viewModel.filteredProcesses) { process in
                    ProcessRow(process: process)
                }
            }
            .listStyle(.plain)
        }
        .onAppear {
            DispatchQueue.main.async {
                viewModel.showProcessMonitor = true
            }
        }
        .onDisappear {
            DispatchQueue.main.async {
                viewModel.showProcessMonitor = false
            }
        }
    }
}

struct ProcessRow: View {
    let process: NetworkProcess
    
    var body: some View {
        HStack(spacing: 10) {
            // 图标与名称
            HStack(spacing: 8) {
                if let icon = process.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "gearshape")
                        .frame(width: 24, height: 24)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(process.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    
                    Text("PID: \(process.id)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 200, alignment: .leading)
            
            Spacer()
            
            // 速度列
            SpeedText(speed: process.downloadSpeed, text: process.formattedDownload)
                .frame(width: 80, alignment: .trailing)
            
            SpeedText(speed: process.uploadSpeed, text: process.formattedUpload)
                .frame(width: 80, alignment: .trailing)
            
            SpeedText(speed: process.totalSpeed, text: process.formattedTotal)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}

struct SpeedText: View {
    let speed: Double
    let text: String
    
    // 阈值常量
    private let thresholdOrange: Double = 1 * 1024 * 1024 // 1 MB/s
    private let thresholdRed: Double = 5 * 1024 * 1024    // 5 MB/s
    
    var color: Color {
        if speed >= thresholdRed {
            return .red
        } else if speed >= thresholdOrange {
            return .orange
        } else {
            return .primary
        }
    }
    
    var body: some View {
        Text(text)
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(color)
    }
}
