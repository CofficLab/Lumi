import Foundation
import KitHTMLPreview

struct PrototypeElementConversationContext: Equatable, Sendable {
    let projectTitle: String
    let projectID: String
    let screenTitle: String
    let screenID: String
    let deviceName: String
    var sourceURL: URL
    let projectRootPath: String?
}

enum PrototypeElementConversationDraftError: Error, Equatable, LocalizedError {
    case draftTooLarge

    var errorDescription: String? {
        switch self {
        case .draftTooLarge:
            PrototypeLocalization.string("The selected element is too large to add to the conversation.")
        }
    }
}

enum PrototypeElementConversationDraftBuilder {
    static let maximumDraftBytes = 48 * 1_024

    static func draft(
        reference: HTMLPreviewElementReference,
        context: PrototypeElementConversationContext
    ) throws -> String {
        try draft(reference: reference, context: context, localize: PrototypeLocalization.string)
    }

    static func draft(
        reference: HTMLPreviewElementReference,
        context: PrototypeElementConversationContext,
        localize: (String) -> String
    ) throws -> String {
        var lines = [
            localize("Please modify this prototype element. I will add the requested change below."),
            "",
            localize("Prototype Element Reference (v1)"),
            "- \(localize("Project")): \(context.projectTitle) (\(context.projectID))",
            "- \(localize("Screen")): \(context.screenTitle) (\(context.screenID))",
            "- \(localize("Device")): \(context.deviceName)",
            "- \(localize("File")): \(safeSourcePath(context))",
            "- \(localize("Element")): \(reference.label)",
            "- \(localize("Selector")): \(reference.selector)",
        ]

        if let blockID = reference.blockID {
            let block = reference.blockLabel.map { "\(blockID) (\($0))" } ?? blockID
            lines.append("- \(localize("Block")): \(block)")
        }
        if reference.isOuterHTMLTruncated {
            lines.append("")
            lines.append(localize("Captured HTML is truncated; read the current screen HTML before editing."))
        }

        let fence = markdownFence(for: reference.outerHTML)
        lines.append(contentsOf: [
            "",
            "\(localize("Current Element HTML")):",
            "\(fence)html",
            reference.outerHTML,
            fence,
        ])

        let result = lines.joined(separator: "\n")
        guard result.utf8.count <= maximumDraftBytes else {
            throw PrototypeElementConversationDraftError.draftTooLarge
        }
        return result
    }

    static func appending(_ draft: String, to existing: String) -> String {
        let current = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        return current.isEmpty ? draft : "\(current)\n\n\(draft)"
    }

    private static func safeSourcePath(_ context: PrototypeElementConversationContext) -> String {
        let source = context.sourceURL.standardizedFileURL
        guard let projectRootPath = context.projectRootPath, !projectRootPath.isEmpty else {
            return source.lastPathComponent
        }
        let root = URL(fileURLWithPath: projectRootPath, isDirectory: true).standardizedFileURL
        let rootPrefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard source.path.hasPrefix(rootPrefix) else {
            return source.lastPathComponent
        }
        return String(source.path.dropFirst(rootPrefix.count))
    }

    private static func markdownFence(for text: String) -> String {
        var longestRun = 0
        var currentRun = 0
        for character in text {
            if character == "`" {
                currentRun += 1
                longestRun = max(longestRun, currentRun)
            } else {
                currentRun = 0
            }
        }
        return String(repeating: "`", count: max(3, longestRun + 1))
    }
}
