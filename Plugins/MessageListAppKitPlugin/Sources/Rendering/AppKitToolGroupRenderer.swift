import AppKit
import Foundation
import KernelLumi

/// Native renderer for a V2 tool-step group row: a collapsed summary of the
/// consecutive tool executions that belong to one assistant step.
@MainActor
final class AppKitToolGroupRenderer: AppKitMessageRenderer {
    let reuseIdentifier = NSUserInterfaceItemIdentifier("AppKitToolGroupRow")

    private let environment: AppKitMessageRendererRegistry.Environment
    private let stack = NSStackView()
    private let summaryLabel = NSTextField(labelWithString: "")

    init(environment: AppKitMessageRendererRegistry.Environment) {
        self.environment = environment
    }

    func makeView() -> NSView {
        let root = NSView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4

        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        summaryLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        summaryLabel.textColor = .secondaryLabelColor

        root.addSubview(summaryLabel)
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            summaryLabel.topAnchor.constraint(equalTo: root.topAnchor, constant: 6),
            summaryLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            summaryLabel.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -12),

            stack.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: 4),
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -6),
        ])
        return root
    }

    func configure(view: NSView, row: AppKitMessageRow) {
        let calls = row.message.toolCalls ?? []
        summaryLabel.stringValue = String(
            format: LumiPluginLocalization.string("Executed · %d calls", bundle: .module),
            calls.count
        )
        stack.arrangedSubviews.forEach { stack.removeArrangedSubview($0) }

        for call in calls {
            let line = NSTextField(labelWithString: "")
            line.font = NSFont.systemFont(ofSize: 12)
            line.lineBreakMode = .byTruncatingTail

            let description = call.displayDescription ?? call.name
            if let result = call.result {
                if result.isError {
                    line.stringValue = "✗ \(description)"
                    line.textColor = .systemRed
                } else {
                    line.stringValue = "✓ \(description)"
                    line.textColor = .labelColor
                }
            } else {
                line.stringValue = "○ \(description)"
                line.textColor = .secondaryLabelColor
            }
            stack.addArrangedSubview(line)
        }
    }

    func prepareForReuse(view: NSView) {
        summaryLabel.stringValue = ""
        stack.arrangedSubviews.forEach { stack.removeArrangedSubview($0) }
    }

    func measure(row: AppKitMessageRow, width: CGFloat) -> CGFloat {
        let count = row.message.toolCalls?.count ?? 0
        return 40 + CGFloat(count) * 20
    }
}
