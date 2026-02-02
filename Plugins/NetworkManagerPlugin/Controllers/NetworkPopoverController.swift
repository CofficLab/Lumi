import AppKit
import SwiftUI

class NetworkPopoverController {
    static let shared = NetworkPopoverController()

    private var popover: NSPopover?
    private var viewModel: NetworkManagerViewModel?

    private init() {}

    func showPopover(from statusItemButton: NSButton) {
        // 如果已经显示，则关闭
        if let popover = popover, popover.isShown {
            closePopover()
            return
        }

        // 在主线程上创建 ViewModel
        Task { @MainActor in
            // 创建新的 Popover
            let popover = NSPopover()
            popover.contentSize = NSSize(width: 500, height: 450)
            popover.behavior = .transient

            // 创建 ViewModel
            let viewModel = NetworkManagerViewModel()
            self.viewModel = viewModel

            // 创建 Hosting View
            let rootView = ProcessNetworkListView(viewModel: viewModel)
            let hostingController = NSHostingController(rootView: rootView)
            popover.contentViewController = hostingController

            self.popover = popover

            // 显示 Popover
            popover.show(relativeTo: statusItemButton.bounds,
                         of: statusItemButton,
                         preferredEdge: .minY)

            // 启动进程监控
            ProcessMonitorService.shared.startMonitoring()

            // 设置回调
            ProcessMonitorService.shared.onUpdate = { [weak self] processes in
                Task { @MainActor in
                    self?.viewModel?.updateProcesses(processes)
                }
            }
        }
    }

    func closePopover() {
        popover?.performClose(nil)
        popover = nil
        viewModel = nil

        // 停止进程监控
        ProcessMonitorService.shared.stopMonitoring()
    }
}
