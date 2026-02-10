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

            // 表头
            GeometryReader { geometry in
                let horizontalPadding: CGFloat = 8
                let scrollBarWidth: CGFloat = 16
                // 计算可用宽度：总宽度 - 左右Padding - 滚动条预留
                let availableWidth = max(0, geometry.size.width - (horizontalPadding * 2) - scrollBarWidth)
                
                HStack(spacing: 0) {
                    Text("应用")
                        .frame(width: availableWidth * 0.50, alignment: .leading)

                    Spacer()

                    Text("下载")
                        .frame(width: availableWidth * 0.2, alignment: .trailing)

                    Text("上传")
                        .frame(width: availableWidth * 0.2, alignment: .trailing)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, horizontalPadding)
                .padding(.trailing, scrollBarWidth) // 表头额外增加右侧Padding以对齐列表内容（避开滚动条）
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            }
            .frame(height: 28)

            Divider()

            // 列表
            if viewModel.filteredProcesses.isEmpty {
                VStack {
                    Spacer()
                    Text("无活跃进程")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else {
                GeometryReader { geometry in
                    List {
                        ForEach(viewModel.filteredProcesses) { process in
                            ProcessRow(process: process, containerWidth: geometry.size.width)
                                .listRowInsets(EdgeInsets()) // 移除系统默认边距
                        }
                    }
                    .listStyle(.plain)
                }
            }
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
        .infiniteWidth()
    }
}



// MARK: - Preview

#Preview("Network Status Bar Popup") {
    NetworkStatusBarPopupView()
        .frame(width: 300)
        .frame(height: 400)
}
