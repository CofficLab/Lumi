import AppKit
import Foundation

/// Empty-state overlay for conversations without persisted messages.
@MainActor
final class AppKitEmptyStateView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(wrappingLabelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .center

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = NSFont.systemFont(ofSize: 11)
        subtitleLabel.textColor = .tertiaryLabelColor
        subtitleLabel.alignment = .center

        addSubview(titleLabel)
        addSubview(subtitleLabel)
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -10),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, subtitle: String) {
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle
    }
}

/// Loading-state overlay shown while the first page loads.
@MainActor
final class AppKitLoadingView: NSView {
    private let indicator = NSProgressIndicator()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.style = .spinning
        indicator.controlSize = .small
        addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            indicator.startAnimation(nil)
        } else {
            indicator.stopAnimation(nil)
        }
    }
}
