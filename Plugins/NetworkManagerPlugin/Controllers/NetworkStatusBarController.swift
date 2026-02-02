import AppKit
import SwiftUI
import Combine

class NetworkStatusBarController {
    static let shared = NetworkStatusBarController()
    
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private var hostingView: NSHostingView<NetworkStatusBarView>?
    
    private init() {}
    
    func start() {
        guard statusItem == nil else { return }
        
        // Start monitoring network
        NetworkService.shared.startMonitoring()
        
        // Create Status Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.isVisible = true
        
        if let button = statusItem?.button {
            // Setup Hosting View
            let view = NetworkStatusBarView()
            let hostingView = NSHostingView(rootView: view)
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            self.hostingView = hostingView
            
            button.addSubview(hostingView)
            
            // Constraints
            NSLayoutConstraint.activate([
                hostingView.topAnchor.constraint(equalTo: button.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
                hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor)
            ])
            
            // Allow clicks to pass through if needed, or handle click
            // For now, let standard button behavior handle clicks (e.g. menu)
        }
    }
    
    func stop() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
        NetworkService.shared.stopMonitoring()
    }
}
