import AppKit
import SwiftUI

private typealias L = AppIconDesignerLocalization

/// Source-file browser injected into the workspace Rail. Shows project- and app-scope
/// document libraries as two collapsible sections, mirroring the Promo Designer rail.
public struct AppIconDesignerRailView: View {
    @ObservedObject private var documentStore = IconDocumentStore.shared
    @State private var expandedScopes: Set<IconScope> = [.project, .app]

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L.string("Icon Documents"))
                    .font(.headline)
                Spacer()
                Text("\(totalCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    createDocument()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help(L.string("New Icon Document"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if documentStore.appStoragePath.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "app.dashed")
                        .foregroundStyle(.secondary)
                    Text(L.string("Ask the Agent to create an icon document."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(16)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        scopeSection(.project)
                        scopeSection(.app)
                    }
                    .padding(10)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var totalCount: Int {
        documentStore.projectDocuments.count + documentStore.appDocuments.count
    }

    @ViewBuilder
    private func scopeSection(_ scope: IconScope) -> some View {
        let documents = documentStore.documents(for: scope)
        let isUnavailable = scope == .project && documentStore.projectStoragePath.isEmpty
        IconDesignerScopeSectionView(
            isExpanded: binding(for: scope),
            icon: scope == .project ? "folder" : "app.badge",
            iconColor: scope == .project ? .accentColor : .purple,
            title: scope.displayName(),
            subtitle: subtitle(for: scope),
            count: documents.count,
            isUnavailable: isUnavailable,
            unavailableMessage: L.string("Open a project to enable project-local storage.")
        ) {
            if documents.isEmpty {
                Text(L.string("No icon documents yet."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
                    .padding(.leading, 20)
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(documents) { document in
                        documentRow(document, scope: scope)
                    }
                }
            }
        }
    }

    private func subtitle(for scope: IconScope) -> String {
        switch scope {
        case .project:
            if let path = documentStore.currentProjectPath?.split(separator: "/").last {
                return "· \(path)"
            }
            return ""
        case .app:
            return ""
        }
    }

    private func binding(for scope: IconScope) -> Binding<Bool> {
        Binding(
            get: { expandedScopes.contains(scope) },
            set: { isExpanded in
                if isExpanded {
                    expandedScopes.insert(scope)
                } else {
                    expandedScopes.remove(scope)
                }
            }
        )
    }

    private func documentRow(_ document: IconDocument, scope: IconScope) -> some View {
        let isSelected = documentStore.selectedScope == scope && documentStore.selectedDocumentId == document.id
        return Button {
            try? documentStore.selectDocument(id: document.id, scope: scope)
        } label: {
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
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                documentStore.deleteDocument(id: document.id, scope: scope)
            } label: {
                Label(L.string("Delete"), systemImage: "trash")
            }
        }
    }

    /// 在可用作用域（优先当前选中作用域）中新建文档。
    private func createDocument() {
        let scope: IconScope
        if !documentStore.storagePath(for: documentStore.selectedScope).isEmpty {
            scope = documentStore.selectedScope
        } else if !documentStore.appStoragePath.isEmpty {
            scope = .app
        } else {
            scope = documentStore.selectedScope
        }
        documentStore.createDocument(
            title: nil,
            width: 1024,
            height: 1024,
            background: .color("#00000000"),
            scope: scope
        )
    }
}

private extension IconDocument {
    var sourceFileName: String {
        "\(fileSafeName)-\(id.prefix(8)).json"
    }
}
