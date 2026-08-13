import AppKit
import Foundation
import KernelLumi

/// Native renderer for one tool call row: description, status, duration,
/// expandable result, and image attachments.
@MainActor
final class AppKitToolRenderer: AppKitMessageRenderer {
    let reuseIdentifier = NSUserInterfaceItemIdentifier("AppKitToolRow")

    private let environment: AppKitMessageRendererRegistry.Environment
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let resultLabel = NSTextField(wrappingLabelWithString: "")

    init(environment: AppKitMessageRendererRegistry.Environment) {
        self.environment = environment
    }

    func makeView() -> NSView {
        let root = NSView()

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        iconView.contentTintColor = .secondaryLabelColor

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor

        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        resultLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        resultLabel.textColor = .secondaryLabelColor
        resultLabel.maximumNumberOfLines = 0
        resultLabel.isHidden = true

        root.addSubview(iconView)
        root.addSubview(titleLabel)
        root.addSubview(statusLabel)
        root.addSubview(resultLabel)
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            iconView.topAnchor.constraint(equalTo: root.topAnchor, constant: 8),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -12),
            titleLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),

            statusLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            statusLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 4),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -12),

            resultLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            resultLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            resultLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 4),
            resultLabel.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -8),
        ])
        return root
    }

    func configure(view: NSView, row: AppKitMessageRow) {
        guard let call = row.message.toolCalls?.first else { return }
        titleLabel.stringValue = call.displayDescription ?? call.name

        if let result = call.result {
            if result.isError {
                iconView.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "error")
                iconView.contentTintColor = .systemRed
                statusLabel.stringValue = LumiPluginLocalization.string("Failed", bundle: .module)
                statusLabel.textColor = .systemRed
            } else {
                iconView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "success")
                iconView.contentTintColor = .systemGreen
                var status = LumiPluginLocalization.string("Done", bundle: .module)
                if let duration = result.duration {
                    status += " · \(Self.formatDuration(duration))"
                }
                statusLabel.stringValue = status
                statusLabel.textColor = .secondaryLabelColor
            }
            resultLabel.stringValue = result.content
            resultLabel.isHidden = result.content.isEmpty
        } else {
            iconView.image = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: "tool")
            iconView.contentTintColor = .secondaryLabelColor
            statusLabel.stringValue = LumiPluginLocalization.string("Executing…", bundle: .module)
            statusLabel.textColor = .secondaryLabelColor
            resultLabel.stringValue = ""
            resultLabel.isHidden = true
        }
    }

    func prepareForReuse(view: NSView) {
        titleLabel.stringValue = ""
        statusLabel.stringValue = ""
        resultLabel.stringValue = ""
        resultLabel.isHidden = true
        iconView.image = nil
    }

    func measure(row: AppKitMessageRow, width: CGFloat) -> CGFloat {
        guard let call = row.message.toolCalls?.first else { return 40 }
        let hasResult = call.result.map { !$0.content.isEmpty } ?? false
        if hasResult {
            let label = NSTextField(wrappingLabelWithString: call.result?.content ?? "")
            label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            label.frame = NSRect(x: 0, y: 0, width: max(80, width - 24), height: .greatestFiniteMagnitude)
            label.sizeToFit()
            return 36 + label.frame.height
        }
        return 40
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 { return "\(Int(duration * 1000))ms" }
        return String(format: "%.1fs", duration)
    }
}

// MARK: - Image attachments

/// Renders `LumiImageAttachment` payloads (base64 → NSImage preview).
@MainActor
enum AppKitAttachmentRenderer {
    /// Decodes an attachment's base64 data.
    static func data(for attachment: LumiImageAttachment) -> Data? {
        Data(base64Encoded: attachment.base64Data)
    }

    /// Builds a preview image view for an attachment (nil when undecodable).
    static func imageView(for attachment: LumiImageAttachment) -> NSImageView? {
        guard let data = data(for: attachment), let image = NSImage(data: data) else { return nil }
        let view = NSImageView(image: image)
        view.imageScaling = .scaleProportionallyUpOrDown
        view.frame.size = NSSize(width: 120, height: 90)
        view.toolTip = attachment.fileName ?? attachment.mimeType
        return view
    }

    /// Writes the attachment to a temp file and opens it with the default app.
    static func open(_ attachment: LumiImageAttachment) {
        guard let data = data(for: attachment) else { return }
        let ext = attachment.mimeType.components(separatedBy: "/").last ?? "img"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-attachment-\(attachment.id.uuidString).\(ext)")
        try? data.write(to: url)
        NSWorkspace.shared.open(url)
    }
}
