import Foundation

enum EditorInteractionUpdateController {
    static func resolve(
        _ update: EditorInteractionUpdate,
        currentViewState: EditorViewState
    ) -> ResolvedEditorInteractionUpdate {
        switch update {
        case let .sourceEditorBinding(bindingUpdate):
            let bridgeState = if let viewState = bindingUpdate.viewState {
                EditorBridgeStateController.state(
                    viewState: viewState,
                    findReplaceState: bindingUpdate.findReplaceState
                )
            } else {
                EditorBridgeStateController.state(
                    viewState: currentViewState,
                    findReplaceState: bindingUpdate.findReplaceState
                )
            }

            return ResolvedEditorInteractionUpdate(
                bridgeState: bridgeState,
                scrollState: nil
            )

        case let .findReplace(state):
            return ResolvedEditorInteractionUpdate(
                bridgeState: EditorBridgeStateController.state(
                    viewState: currentViewState,
                    findReplaceState: state
                ),
                scrollState: nil
            )

        case let .scroll(state):
            return ResolvedEditorInteractionUpdate(
                bridgeState: nil,
                scrollState: state
            )

        case let .cursor(update):
            return ResolvedEditorInteractionUpdate(
                bridgeState: EditorBridgeStateController.state(for: update),
                scrollState: nil
            )

        case let .explicitCursor(positions, fallbackLine, fallbackColumn):
            return ResolvedEditorInteractionUpdate(
                bridgeState: EditorBridgeStateController.state(
                    cursorPositions: positions,
                    fallbackLine: fallbackLine,
                    fallbackColumn: fallbackColumn
                ),
                scrollState: nil
            )

        case let .sessionRestore(result):
            return ResolvedEditorInteractionUpdate(
                bridgeState: EditorBridgeStateController.state(from: result),
                scrollState: result.scrollState
            )
        }
    }
}
