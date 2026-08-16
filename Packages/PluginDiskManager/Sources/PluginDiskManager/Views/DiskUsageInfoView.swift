import SwiftUI
import LumiUI

/// 磁盘使用情况信息卡（环形图 + 总/已用/可用）。
///
/// 已从原 ``DiskManagerView`` 提取为独立视图，挂在 rail view
/// （``DiskCleanupCategorySidebar``）的标题下方，磁盘使用情况刷新由本视图内部
/// 的 ``DiskManagerViewModel`` 负责。
struct DiskUsageInfoView: View {
    @StateObject private var viewModel = DiskManagerViewModel()

    var body: some View {
        AppCard(padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 12) {
                    DiskUsageRingView()
                        .frame(width: 64, height: 64)

                    if let usage = viewModel.diskUsage {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(PluginDiskManagerLocalization.string("Macintosh HD"))
                                .font(.appBodyEmphasized)
                                .foregroundColor(.primary)

                            infoRow(label: PluginDiskManagerLocalization.string("总计："), value: formatBytes(usage.total), color: .primary)
                            infoRow(label: PluginDiskManagerLocalization.string("已用："), value: formatBytes(usage.used), color: Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                            infoRow(label: PluginDiskManagerLocalization.string("可用："), value: formatBytes(usage.available), color: Color(hex: "30D158"))
                        }
                    } else {
                        ProgressView()
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .onAppear {
            viewModel.refreshDiskUsage()
        }
    }

    @ViewBuilder
    private func infoRow(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.appCaption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.appCaption)
                .foregroundColor(color)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        DiskManagerViewModel.byteFormatter.string(fromByteCount: bytes)
    }
}

#if DEBUG
#Preview("Disk Usage") {
    DiskUsageInfoView()
        .frame(width: 240)
        .padding()
}
#endif