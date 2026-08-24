import SwiftUI
import KernelLumi

/// Thin SwiftUI ↔ AppKit bridge for the native message-list view.
///
/// This is the only place (besides the plugin entry point) where SwiftUI is
/// allowed: everything below the bridge is AppKit. No message rendering
/// happens here.
struct MessageListAppKitBridge: NSViewControllerRepresentable {
    let kernel: KernelLumi

    func makeNSViewController(context: Context) -> AppKitMessageListViewController {
        AppKitMessageListViewController(kernel: kernel)
    }

    func updateNSViewController(_ controller: AppKitMessageListViewController, context: Context) {
        // The controller reads kernel services at `viewDidLoad`; nothing to
        // propagate on updates.
    }
}
