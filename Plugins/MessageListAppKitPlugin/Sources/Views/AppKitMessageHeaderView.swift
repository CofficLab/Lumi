import AppKit
import Foundation
import LumiKernel

/// Compact message header: timestamp, token usage, copy button, optional
/// resend button (wired through the registry environment).
@MainActor
final class AppKitMessageHeaderView: NSView {
    static let headerHeight: CGFloat = 22

    private let timestampLabel = NSTextField(labelWithString: "")
    private let tokensLabel = NSTextField(labelWithString: "")
    private let copyButton = NSButton(title: "", target: nil, action: nil)

    private var onCopy: (() -> Void)?
    private var onResend: (() -> Void)?

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        timestampLabel.translatesAutoresizingMaskIntoConstraints = false
        timestampLabel.font = NSFont.systemFont(ofSize: 10)
        timestampLabel.textColor = .secondaryLabelColor

        tokensLabel.translatesAutoresizingMaskIntoConstraints = false
        tokensLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        tokensLabel.textColor = .tertiaryLabelColor

        copyButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.bezelStyle = .inline
        copyButton.controlSize = .mini
        copyButton.font = NSFont.systemFont(ofSize: 10)
        copyButton.title = "复制"
        copyButton.target = self
        copyButton.action = #selector(copyPressed)

        addSubview(timestampLabel)
        addSubview(tokensLabel)
        addSubview(copyButton)
        NSLayoutConstraint.activate([
            timestampLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            timestampLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            tokensLabel.leadingAnchor.constraint(equalTo: timestampLabel.trailingAnchor, constant: 10),
            tokensLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            copyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            copyButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: Self.headerHeight),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(message: LumiChatMessage) {
        timestampLabel.stringValue = Self.timeFormatter.string(from: message.createdAt)

        var parts: [String] = []
        if let input = message.inputTokenCount, let output = message.outputTokenCount {
            parts.append("\(Self.formatToken(input))/\(Self.formatToken(output)) tokens")
        }
        if let latency = message.latencyMs {
            parts.append(Self.formatMilliseconds(latency))
        }
        tokensLabel.stringValue = parts.joined(separator: " · ")

        onCopy = {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(message.content, forType: .string)
        }
    }

    override func prepareForReuse() {
        timestampLabel.stringValue = ""
        tokensLabel.stringValue = ""
        onCopy = nil
        onResend = nil
    }

    private static func formatMilliseconds(_ ms: Double) -> String {
        if ms < 1000 { return "\(Int(ms.rounded()))ms" }
        return String(format: "%.1fs", ms / 1000.0)
    }

    private static func formatToken(_ count: Int) -> String {
        if count >= 1000 {
            let k = Double(count) / 1000.0
            return k >= 10 ? String(format: "%.0fk", k) : String(format: "%.1fk", k)
        }
        return String(count)
    }

    @objc private func copyPressed() {
        onCopy?()
    }
}
