import AppKit
import Foundation

/// Temporary plain-text renderer used by the table shell (Task 6) until the
/// full native renderer registry lands in Task 11.
///
/// Renders the message content as a wrapping label with the role name as a
/// small header, so every row type is visually distinguishable during
/// evaluation while the reuse machinery is exercised for real.
@MainActor
final class AppKitFallbackRenderer: AppKitMessageRenderer {
    let reuseIdentifier = NSUserInterfaceItemIdentifier("AppKitFallbackRow")

    func makeView() -> NSView {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let header = NSTextField(labelWithString: "")
        header.translatesAutoresizingMaskIntoConstraints = false
        header.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        header.textColor = .secondaryLabelColor
        header.lineBreakMode = .byTruncatingTail
        header.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let body = NSTextField(wrappingLabelWithString: "")
        body.translatesAutoresizingMaskIntoConstraints = false
        body.font = NSFont.systemFont(ofSize: 13)
        body.textColor = .labelColor
        body.maximumNumberOfLines = 0
        body.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        root.addSubview(header)
        root.addSubview(body)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: root.topAnchor, constant: 8),
            header.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            header.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -12),

            body.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 2),
            body.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            body.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            body.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -8),
        ])

        root.identifier = NSUserInterfaceItemIdentifier("fallbackRoot")
        root.setAccessibilityLabel("message")
        return root
    }

    func configure(view: NSView, row: AppKitMessageRow) {
        guard let header = view.subviews.first as? NSTextField,
              let body = view.subviews.dropFirst().first as? NSTextField else { return }
        header.stringValue = row.role.rawValue
        body.stringValue = row.content.isEmpty ? "(empty)" : row.content
        view.setAccessibilityLabel("\(row.role.rawValue) message: \(row.content)")
    }

    func prepareForReuse(view: NSView) {
        for subview in view.subviews {
            (subview as? NSTextField)?.stringValue = ""
        }
    }

    func measure(row: AppKitMessageRow, width: CGFloat) -> CGFloat {
        // Fixed-height placeholder until the TextKit layout cache lands.
        72
    }
}
