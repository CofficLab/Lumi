import LumiUI
import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: ProjectsViewModel
    let requestImporter: () -> Void

    var body: some View {
        ListView(viewModel: viewModel, addProject: requestImporter)
            .frame(width: 320)
            .frame(minHeight: 220, maxHeight: 420)
    }
}
