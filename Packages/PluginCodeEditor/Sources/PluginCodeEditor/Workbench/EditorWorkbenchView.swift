import EditorContracts
import SwiftUI

public struct EditorWorkbenchView: View {
    @ObservedObject private var viewModel: CodeEditorViewModel
    private let surface: any EditorSurfaceProviding

    public init(
        viewModel: CodeEditorViewModel,
        surface: any EditorSurfaceProviding
    ) {
        self.viewModel = viewModel
        self.surface = surface
    }

    public var body: some View {
        surface.makeEditorView()
            .id(viewModel.currentFileURL)
    }
}
