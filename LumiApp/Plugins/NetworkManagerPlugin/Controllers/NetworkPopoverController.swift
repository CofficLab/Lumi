import AppKit
import SwiftUI

@MainActor
class NetworkPopoverController {
    static let shared = NetworkPopoverController()

    private var popover: NSPopover?
    private var viewModel: NetworkManagerViewModel?

    private init() {}

    func showPopover(from statusItemButton: NSButton) {
        // Close if already shown
        if let popover = popover, popover.isShown {
            closePopover()
            return
        }

        // Create new Popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 500, height: 450)
        popover.behavior = .transient

        // Create ViewModel
        let viewModel = NetworkManagerViewModel()
        self.viewModel = viewModel

        // Create Hosting View
        let rootView = ProcessNetworkListView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: rootView)
        popover.contentViewController = hostingController

        self.popover = popover

        // Show Popover
        popover.show(relativeTo: statusItemButton.bounds,
                     of: statusItemButton,
                     preferredEdge: .minY)

        // Start process monitoring
        ProcessMonitorService.shared.startMonitoring()
    }

    func closePopover() {
        popover?.performClose(nil)
        popover = nil
        viewModel = nil

        // Stop process monitoring
        ProcessMonitorService.shared.stopMonitoring()
    }
}
