import KitHTMLPreview
import KitPrototype
import ProviderConversationInput

enum PrototypeElementConversationActionOutcome: Equatable {
    case appended
    case unavailable
    case staleSelection
}

@MainActor
enum PrototypeElementConversationAction {
    static func apply(
        reference: HTMLPreviewElementReference,
        resolved: PrototypeResolvedScreen,
        currentProjectPath: String?,
        selectedProjectID: String?,
        selectedScreenID: String?,
        input: (any ConversationInputProviding)?
    ) throws -> PrototypeElementConversationActionOutcome {
        guard selectedProjectID == resolved.project.id,
              selectedScreenID == resolved.screen.id else {
            return .staleSelection
        }
        guard let input else { return .unavailable }

        let context = PrototypeElementConversationContext(
            projectTitle: resolved.project.title,
            projectID: resolved.project.id,
            screenTitle: resolved.screen.title,
            screenID: resolved.screen.id,
            deviceName: resolved.project.device.kind.displayName,
            sourceURL: resolved.htmlURL,
            projectRootPath: currentProjectPath
        )
        let draft = try PrototypeElementConversationDraftBuilder.draft(
            reference: reference,
            context: context
        )
        input.text = PrototypeElementConversationDraftBuilder.appending(draft, to: input.text)
        input.isInputFocused = true
        return .appended
    }
}
