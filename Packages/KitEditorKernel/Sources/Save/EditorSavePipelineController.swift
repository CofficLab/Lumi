import Foundation

public enum EditorDeferredSaveAction: String, CaseIterable, Equatable, Sendable {
    case organizeImports
    case fixAll
}

public struct EditorSavePipelineOptions: Equatable, Sendable {
    public var textParticipants: EditorSaveParticipantOptions
    public var formatOnSave: Bool
    public var organizeImportsOnSave: Bool
    public var fixAllOnSave: Bool

    public static let `default` = EditorSavePipelineOptions(
        textParticipants: .default,
        formatOnSave: false,
        organizeImportsOnSave: false,
        fixAllOnSave: false
    )

    public init(
        textParticipants: EditorSaveParticipantOptions,
        formatOnSave: Bool,
        organizeImportsOnSave: Bool,
        fixAllOnSave: Bool
    ) {
        self.textParticipants = textParticipants
        self.formatOnSave = formatOnSave
        self.organizeImportsOnSave = organizeImportsOnSave
        self.fixAllOnSave = fixAllOnSave
    }
}

public struct EditorSavePipelineResult: Equatable, Sendable {
    public let text: String
    public let didApplyTextParticipants: Bool
    public let didFormat: Bool
    public let deferredActions: [EditorDeferredSaveAction]

    public var changed: Bool {
        didApplyTextParticipants || didFormat
    }

    public init(
        text: String,
        didApplyTextParticipants: Bool,
        didFormat: Bool,
        deferredActions: [EditorDeferredSaveAction]
    ) {
        self.text = text
        self.didApplyTextParticipants = didApplyTextParticipants
        self.didFormat = didFormat
        self.deferredActions = deferredActions
    }
}

public enum EditorSavePipelineController {
    @MainActor
    public static func prepare(
        text: String,
        options: EditorSavePipelineOptions = .default,
        tabSize: Int,
        insertSpaces: Bool,
        formatDocument: ((_ text: String, _ tabSize: Int, _ insertSpaces: Bool) async -> String?)? = nil
    ) async -> EditorSavePipelineResult {
        let participantResult = EditorSaveParticipantController.prepare(
            text: text,
            options: options.textParticipants
        )

        var transformed = participantResult.text
        var didFormat = false

        if options.formatOnSave,
           let formatDocument,
           let formatted = await formatDocument(transformed, tabSize, insertSpaces),
           formatted != transformed {
            transformed = formatted
            didFormat = true
        }

        var deferredActions: [EditorDeferredSaveAction] = []
        if options.organizeImportsOnSave {
            deferredActions.append(.organizeImports)
        }
        if options.fixAllOnSave {
            deferredActions.append(.fixAll)
        }

        return EditorSavePipelineResult(
            text: transformed,
            didApplyTextParticipants: participantResult.changed,
            didFormat: didFormat,
            deferredActions: deferredActions
        )
    }
}
