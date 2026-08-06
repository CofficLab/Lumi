import AppKit
import Foundation

/// "Load earlier messages" row shown above the message list when an earlier
/// page exists. Clicking it requests one more page via the coordinator.
@MainActor
final class AppKitLoadEarlierCellView: NSTableCellView {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("AppKitLoadEarlierRow")

    var onLoadEarlier: (() -> Void)?

    private let button: NSButton

    override init(frame frameRect: NSRect) {
        let button = NSButton(title: "", target: nil, action: nil)
        button.bezelStyle = .rounded
        button.isBordered = true
        button.controlSize = .small
        button.translatesAutoresizingMaskIntoConstraints = false
        self.button = button

        super.init(frame: frameRect)

        addSubview(button)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: centerXAnchor),
            button.centerYAnchor.constraint(equalTo: centerYAnchor),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
        ])
        button.target = self
        button.action = #selector(loadEarlierPressed)
        identifier = Self.reuseIdentifier
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String) {
        button.title = title
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        button.title = ""
    }

    @objc private func loadEarlierPressed() {
        onLoadEarlier?()
    }
}
