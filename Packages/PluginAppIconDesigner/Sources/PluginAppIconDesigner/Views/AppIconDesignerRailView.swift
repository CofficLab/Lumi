import LumiUI
import SwiftUI

private typealias L = AppIconDesignerLocalization

/// Project-local icon document browser injected into the workspace Rail.
public struct AppIconDesignerRailView: View {
    @ObservedObject private var viewModel: AppIconDesignerViewModel
    @LumiTheme private var theme

    init(viewModel: AppIconDesignerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppToolbarContainer {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    AppToolbarTitleLabel(title: L.string("Icon Documents"))
                    AppTag("\(viewModel.totalCount)", style: .subtle)
                    Spacer(minLength: 0)
                    AppIconButton(systemImage: "plus", action: createDocument)
                        .accessibilityLabel(L.string("New Icon Document"))
                        .help(L.string("New Icon Document"))
                    AppIconButton(systemImage: "arrow.clockwise", action: viewModel.reload)
                        .accessibilityLabel(L.string("Refresh"))
                        .help(L.string("Refresh"))
                }
            }
            .borderBottom()

            if viewModel.projectStoragePath.isEmpty {
                AppEmptyState(
                    icon: "folder",
                    title: L.string("Open a project to enable project-local storage.")
                )
            } else if viewModel.projectDocuments.isEmpty {
                AppEmptyState(
                    icon: "app.dashed",
                    title: L.string("Ask the Agent to create an icon document.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignTokens.Spacing.xs) {
                        ForEach(viewModel.projectDocuments) { document in
                            documentRow(document)
                        }
                    }
                    .padding(DesignTokens.Spacing.sm)
                }
            }
        }
        .background(theme.background)
    }

    private func documentRow(_ document: IconDocument) -> some View {
        AppListRow(
            isSelected: viewModel.selectedDocumentId == document.id,
            action: { try? viewModel.selectDocument(id: document.id, scope: .project) }
        ) {
            HStack(spacing: 9) {
                IconRenderedDocumentView(document: document)
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(document.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(document.sourceFileName)
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                viewModel.deleteDocument(id: document.id, scope: .project)
            } label: {
                Label(L.string("Delete"), systemImage: "trash")
            }
        }
    }

    private func createDocument() {
        guard !viewModel.projectStoragePath.isEmpty else { return }
        viewModel.createDocument(
            title: nil,
            width: 1024,
            height: 1024,
            background: .color("#00000000"),
            scope: .project
        )
    }
}

private extension IconDocument {
    var sourceFileName: String {
        "\(fileSafeName)-\(id.prefix(8)).json"
    }
}
