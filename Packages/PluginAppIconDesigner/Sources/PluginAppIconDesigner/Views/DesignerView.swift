import AppKit
import SwiftUI

private typealias L = AppIconDesignerLocalization

/// Main canvas for the icon designer. Editing is intentionally agent-driven;
/// this view only previews the selected source document and exposes exports.
public struct DesignerView: View {
    @ObservedObject private var documentStore = IconDocumentStore.shared
    @State private var isExporting = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if let document = documentStore.selectedDocument {
                preview(document: document)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "app.dashed")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(L.string("App Icon Designer"))
                    .font(.headline)
                if let document = documentStore.selectedDocument {
                    Text(document.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            IconDesignerScopeBadge(scope: documentStore.selectedScope)
                .help(L.string("Current storage scope"))

            Spacer()

            if let document = documentStore.selectedDocument {
                Button {
                    Task { await exportSVG(document) }
                } label: {
                    Label(L.string("Export SVG"), systemImage: "square.and.arrow.down")
                }
                .disabled(isExporting)

                Button {
                    Task { await exportXcodeIcon(document) }
                } label: {
                    Label(L.string("Export Xcode Icon"), systemImage: "app.dashed")
                }
                .disabled(isExporting)
                .help(L.string("Export an AppIcon.icon for macOS 15 and later"))
            }

            if isExporting {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func preview(document: IconDocument) -> some View {
        VStack(spacing: 18) {
            Spacer()

            IconRenderedDocumentView(document: document)
                .frame(width: 420, height: 420)
                .clipShape(RoundedRectangle(cornerRadius: 72, style: .continuous))
                .shadow(color: .black.opacity(0.14), radius: 28, y: 14)

            VStack(spacing: 5) {
                Text(document.title)
                    .font(.title3.weight(.semibold))
                Text(L.format("%lld × %lld · %lld layers", Int64(document.width), Int64(document.height), Int64(document.layers.count)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let url = documentStore.lastExportURL {
                Label(url.path, systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 24)
            }

            if let error = documentStore.lastError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "app.dashed")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text(L.string("No icon document selected"))
                .font(.title3.weight(.semibold))
            Text(L.string("Ask the Agent to create or load an icon document."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func exportSVG(_ document: IconDocument) async {
        guard let directoryURL = pickDirectory(title: L.string("Choose export location for SVG")) else { return }

        isExporting = true
        defer { isExporting = false }

        do {
            let url = directoryURL.appendingPathComponent("\(document.fileSafeName).svg")
            try IconSVGRenderer().render(document: document).write(to: url, atomically: true, encoding: .utf8)
            documentStore.setExportURL(url)
        } catch {
            documentStore.setError(error.localizedDescription)
        }
    }

    private func exportXcodeIcon(_ document: IconDocument) async {
        guard let directoryURL = pickDirectory(title: L.string("Choose export location for Xcode Icon")) else { return }

        isExporting = true
        defer { isExporting = false }

        do {
            let result = try IconComposerExportService().export(
                document: document,
                outputDirectory: directoryURL
            )
            documentStore.setExportURL(result.iconURL)
        } catch {
            documentStore.setError(error.localizedDescription)
        }
    }

    /// Presents an NSOpenPanel for directory selection and returns the chosen URL.
    private func pickDirectory(title: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = L.string("Choose")
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return url
    }
}

extension IconDocument {
    var fileSafeName: String {
        let safe = title
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9_-]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return safe.isEmpty ? "icon" : safe
    }
}

private struct AppIconImageView: View {
    let path: String

    var body: some View {
        if let image = NSImage(contentsOfFile: path) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color(nsColor: .separatorColor).opacity(0.2)
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
