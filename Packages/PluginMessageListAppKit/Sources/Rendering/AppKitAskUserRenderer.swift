import AppKit
import Foundation
import KernelLumi

/// Interactive native renderer for a suspended `ask_user` tool call.
///
/// Renders yes/no, choice, and free-text controls from the wire payload.
/// Submitting calls `messageSender.resumeTurn` once, disables every control
/// immediately, and restores pristine state on reuse (duplicate-submit guard
/// is per-renderer-instance, reset by `prepareForReuse`).
@MainActor
final class AppKitAskUserRenderer: AppKitMessageRenderer {
    let reuseIdentifier = NSUserInterfaceItemIdentifier("AppKitAskUserRow")

    private let environment: AppKitMessageRendererRegistry.Environment
    private var payload: AppKitAskUserPayload?
    private var responded = false
    private var conversationID: UUID?

    private let questionLabel = NSTextField(wrappingLabelWithString: "")
    private let controlsStack = NSStackView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let freeTextField = NSTextField()
    private let submitButton = NSButton(title: LumiPluginLocalization.string("Submit", bundle: .module), target: nil, action: nil)

    init(environment: AppKitMessageRendererRegistry.Environment) {
        self.environment = environment
    }

    func makeView() -> NSView {
        let root = NSView()

        questionLabel.translatesAutoresizingMaskIntoConstraints = false
        questionLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        questionLabel.textColor = .labelColor
        questionLabel.maximumNumberOfLines = 0

        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        controlsStack.orientation = .vertical
        controlsStack.alignment = .leading
        controlsStack.spacing = 6

        freeTextField.translatesAutoresizingMaskIntoConstraints = false
        freeTextField.placeholderString = LumiPluginLocalization.string("Input your answer", bundle: .module)
        freeTextField.isHidden = true
        freeTextField.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true

        submitButton.translatesAutoresizingMaskIntoConstraints = false
        submitButton.bezelStyle = .rounded
        submitButton.controlSize = .small
        submitButton.title = LumiPluginLocalization.string("Submit", bundle: .module)
        submitButton.isHidden = true
        submitButton.target = self
        submitButton.action = #selector(submitPressed)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor

        root.addSubview(questionLabel)
        root.addSubview(controlsStack)
        root.addSubview(freeTextField)
        root.addSubview(submitButton)
        root.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            questionLabel.topAnchor.constraint(equalTo: root.topAnchor, constant: 8),
            questionLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            questionLabel.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -12),

            controlsStack.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 8),
            controlsStack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            controlsStack.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -12),

            freeTextField.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 8),
            freeTextField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            freeTextField.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -72),

            submitButton.leadingAnchor.constraint(equalTo: freeTextField.trailingAnchor, constant: 6),
            submitButton.centerYAnchor.constraint(equalTo: freeTextField.centerYAnchor),

            statusLabel.topAnchor.constraint(equalTo: controlsStack.bottomAnchor, constant: 6),
            statusLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            statusLabel.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -8),
        ])
        return root
    }

    func configure(view: NSView, row: AppKitMessageRow) {
        guard let payload = Self.pendingPayload(in: row.message) else {
            questionLabel.stringValue = LumiPluginLocalization.string("Cannot parse question", bundle: .module)
            statusLabel.stringValue = ""
            controlsStack.arrangedSubviews.forEach { controlsStack.removeArrangedSubview($0) }
            freeTextField.isHidden = true
            submitButton.isHidden = true
            return
        }

        self.payload = payload
        self.conversationID = UUID(uuidString: payload.conversationId)
        self.responded = false

        questionLabel.stringValue = payload.question
        statusLabel.stringValue = ""
        freeTextField.stringValue = ""
        freeTextField.isHidden = true
        submitButton.isHidden = true
        controlsStack.arrangedSubviews.forEach { controlsStack.removeArrangedSubview($0) }

        switch payload.effectiveMode {
        case .yesNo, .choice:
            for option in payload.options {
                let button = NSButton(title: option.label, target: self, action: #selector(optionPressed(_:)))
                button.bezelStyle = .rounded
                button.controlSize = .small
                button.tag = controlsStack.arrangedSubviews.count
                controlsStack.addArrangedSubview(button)
            }
        case .freeText:
            freeTextField.isHidden = false
            submitButton.isHidden = false
        }
    }

    func prepareForReuse(view: NSView) {
        payload = nil
        conversationID = nil
        responded = false
        questionLabel.stringValue = ""
        statusLabel.stringValue = ""
        freeTextField.stringValue = ""
        freeTextField.isHidden = true
        submitButton.isHidden = true
        controlsStack.arrangedSubviews.forEach { controlsStack.removeArrangedSubview($0) }
    }

    func measure(row: AppKitMessageRow, width: CGFloat) -> CGFloat {
        guard let payload = Self.pendingPayload(in: row.message) else {
            return 44
        }
        switch payload.effectiveMode {
        case .yesNo, .choice:
            return 44 + CGFloat(max(1, payload.options.count)) * 30
        case .freeText:
            return 96
        }
    }

    // MARK: - Actions

    @objc private func optionPressed(_ sender: NSButton) {
        guard let payload, !responded else { return }
        submitAnswer(sender.title)
    }

    @objc private func submitPressed() {
        guard let payload, !responded else { return }
        let answer = freeTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else { return }
        submitAnswer(answer)
    }

    private func submitAnswer(_ answer: String) {
        guard !responded, let payload, let conversationID,
              let sender = environment.messageSender else { return }
        responded = true
        setControlsEnabled(false)
        statusLabel.stringValue = LumiPluginLocalization.string("Submitted", bundle: .module)

        Task { @MainActor in
            _ = try? await sender.resumeTurn(
                in: conversationID,
                request: AgentTurnResumeRequest(
                    suspensionID: payload.toolCallId,
                    answer: answer
                )
            )
        }
    }

    private static func pendingPayload(in message: LumiChatMessage) -> AppKitAskUserPayload? {
        message.toolCalls?.lazy.compactMap { call in
            guard call.result?.turnControl.isSuspended == true else { return nil }
            return AppKitAskUserPayload.parse(from: call.result?.content)
        }.first
    }

    private func setControlsEnabled(_ enabled: Bool) {
        for subview in controlsStack.arrangedSubviews {
            (subview as? NSButton)?.isEnabled = enabled
        }
        submitButton.isEnabled = enabled
        freeTextField.isEnabled = enabled
    }
}
