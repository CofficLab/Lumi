import EditorService
import Foundation
import LumiCoreKit
import SwiftUI

@MainActor
public final class SwiftBuildOutputPanelContributor: SuperEditorPanelContributor {
    public let id: String = "swift.build-output"

    public init() {}

    public func providePanels(state: EditorState) -> [EditorPanelSuggestion] {
        guard state.detectedLanguage?.tsName == "swift" else { return [] }
        let buildRunManager = EditorSwiftWindowScopeRegistry.activeBuildRunManager
        guard shouldShow(buildRunManager: buildRunManager, state: state) else { return [] }

        return [
            EditorPanelSuggestion(
                id: "swift.build-output",
                title: LumiPluginLocalization.string("Build", bundle: .module),
                systemImage: "play.fill",
                placement: .bottom,
                order: 480,
                isPresented: { state in
                    guard state.detectedLanguage?.tsName == "swift" else { return false }
                    let manager = EditorSwiftWindowScopeRegistry.activeBuildRunManager
                    return manager.phase != .idle
                        || !manager.issues.isEmpty
                        || manager.hasAnyStageOutput
                },
                onDismiss: { _ in },
                content: { _ in
                    AnyView(
                        SwiftBuildOutputView(
                            buildRunManager: EditorSwiftWindowScopeRegistry.activeBuildRunManager
                        )
                    )
                }
            ),
        ]
    }

    private func shouldShow(buildRunManager: SwiftBuildRunManager, state: EditorState) -> Bool {
        guard state.detectedLanguage?.tsName == "swift" else { return false }
        return buildRunManager.phase != .idle
            || !buildRunManager.issues.isEmpty
            || buildRunManager.hasAnyStageOutput
    }
}
