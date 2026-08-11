import AppKit
import SwiftUI

private typealias L = AppIconDesignerLocalization

/// Source-file browser injected into the workspace Rail.
public struct AppIconDesignerRailView: View {
    @ObservedObject private var documentStore = IconDocumentStore.shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L.string("Icon Documents"))
                    .font(.headline)
                Spacer()
                Text("\(documentStore.documents.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    documentStore.createDocument(
                        title: nil,
                        width: 1024,
                        height: 1024,
                        background: .color("#00000000")
                    )
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help(L.string("New Icon Document"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if documentStore.documents.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.badge.plus")
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
                    LazyVStack(spacing: 6) {
                        ForEach(documentStore.documents) { document in
                            documentRow(document)
                        }
                    }
                    .padding(10)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func documentRow(_ document: IconDocument) -> some View {
        let isSelected = documentStore.selectedDocumentId == document.id
        return Button {
            try? documentStore.selectDocument(id: document.id)
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
                documentStore.deleteDocument(id: document.id)
            } label: {
                Label(L.string("Delete"), systemImage: "trash")
            }
        }
    }
}

private extension IconDocument {
    var sourceFileName: String {
        "\(fileSafeName)-\(id.prefix(8)).json"
    }
}
