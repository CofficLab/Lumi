import SwiftUI

// MARK: - Local Notification Names

extension Notification.Name {
    static let lumiMenuBarAppearanceDidChange = Notification.Name("lumiMenuBarAppearanceDidChange")
}

/// 菜单栏内容视图（CPU 每核瞬时柱状图 + 内存单柱）
public struct DeviceInfoMenuBarContentView: View {

    // MARK: - Properties

    // 共享 ViewModel 保证 CPU/内存指标持续更新。
    @ObservedObject private var viewModel: DeviceInfoMenuBarContentViewModel

    init(viewModel: DeviceInfoMenuBarContentViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 4) {
            // CPU 柱状图
            Image(nsImage: viewModel.snapshot.cpuImage)
                .interpolation(.none)
                .help(viewModel.snapshot.cpuHelpText)

            // 内存柱状图
            Image(nsImage: viewModel.snapshot.memoryImage)
                .interpolation(.none)
                .help(viewModel.snapshot.memoryHelpText)
        }
    }
}
