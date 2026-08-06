import SwiftUI
import LumiKernel

/// Thin SwiftUI ↔ AppKit bridge for the native message-list view.
///
/// The full AppKit implementation lands in Tasks 4+. This scaffold keeps
/// only the unavoidable `NSViewControllerRepresentable` bridge required by
/// `ChatSectionItem`. No message rendering is performed here.
struct MessageListAppKitBridge: NSViewControllerRepresentable {
    let kernel: LumiKernel

    func makeNSViewController(context: Context) -> MessageListAppKitPlaceholderViewController {
        MessageListAppKitPlaceholderViewController(kernel: kernel)
    }

    func updateNSViewController(_ controller: MessageListAppKitPlaceholderViewController, context: Context) {
        controller.kernel = kernel
    }
}

/// Placeholder controller used while the plugin ships as `.disabled`.
///
/// Renders a single neutral label so the bridge compiles and renders without
/// touching the message rendering pipeline (which is built in later tasks).
@MainActor
final class MessageListAppKitPlaceholderViewController: NSViewController {
    var kernel: LumiKernel

    init(kernel: LumiKernel) {
        self.kernel = kernel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        let label = NSTextField(labelWithString: "MessageListAppKitPlugin (disabled)")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .secondaryLabelColor
        label.alignment = .center

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        self.view = container
    }
}
