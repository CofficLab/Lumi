import LumiUI
import SwiftUI
import UniformTypeIdentifiers
import LumiCoreKit

struct ProjectsPopoverView: View {
    @ObservedObject var viewModel: ProjectsViewModel
    @State private var isImporterPresented = false

    var body: some View {
        ProjectListView(viewModel: viewModel, isImporterPresented: $isImporterPresented)
            .frame(width: 320)
            .frame(minHeight: 220, maxHeight: 420)
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
    }

    private func handleImport(_ result: Result<[URL], any Error>) {
        guard case let .success(urls) = result,
              let url = urls.first
        else {
            return
        }

        viewModel.addProject(url: url)
    }
}
