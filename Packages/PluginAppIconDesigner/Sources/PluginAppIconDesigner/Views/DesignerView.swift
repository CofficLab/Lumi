import AppKit
import LumiUI
import SwiftUI

private typealias L = AppIconDesignerLocalization

/// Main canvas for the icon designer. Editing is agent-driven; this view previews
/// the selected source document and exposes exports in the bottom toolbar.
public struct DesignerView: View {
    @ObservedObject private var viewModel: AppIconDesignerViewModel
    @State private var isExporting = false
    private let onDocumentAvailabilityChanged: ((Bool) -> Void)?

    init(
        viewModel: AppIconDesignerViewModel,
        onDocumentAvailabilityChanged: ((Bool) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onDocumentAvailabilityChanged = onDocumentAvailabilityChanged
    }

    public var body: some View {
        VStack(spacing: 0) {
            if viewModel.projectDocuments.isEmpty {
                emptyToolbar
                IconOnboardingView(isProjectOpen: !viewModel.projectStoragePath.isEmpty)
            } else if let document = viewModel.selectedDocument {
                topToolbar(for: document)
                preview(document: document)
                bottomToolbar(for: document)
            } else {
                IconTaskSelectionView(
                    message: L.string(
                        "Select an icon document from the left, or ask the Agent to create one."
                    )
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            notifyDocumentAvailability()
        }
        .onChange(of: viewModel.projectDocuments.count) { _, _ in
            notifyDocumentAvailability()
        }
    }

    private var emptyToolbar: some View {
        AppToolbarContainer {
            HStack {
                Spacer(minLength: 0)
                AppIconButton(systemImage: "arrow.clockwise", action: viewModel.reload)
                    .accessibilityLabel(L.string("Refresh"))
                    .help(L.string("Refresh"))
            }
        }
        .borderBottom()
    }

    private func topToolbar(for document: IconDocument) -> some View {
        AppToolbarContainer {
            HStack(spacing: DesignTokens.Spacing.sm) {
                AppToolbarTitleLabel(icon: "app.dashed", title: document.title)

                AppTag(L.string("In Project"), systemImage: "folder", style: .subtle)

                if let projectName = viewModel.currentProjectPath?.split(separator: "/").last {
                    Text(projectName)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
        }
        .borderBottom()
    }

    private func bottomToolbar(for document: IconDocument) -> some View {
        AppToolbarContainer {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Spacer(minLength: 0)

                AppButton(
                    L.string("Export SVG"),
                    systemImage: "square.and.arrow.down",
                    style: .secondary,
                    size: .small
                ) {
                    Task { await exportSVG(document) }
                }
                .disabled(isExporting)

                AppButton(
                    L.string("Export Xcode Icon"),
                    systemImage: "app.dashed",
                    style: .secondary,
                    size: .small
                ) {
                    Task { await exportXcodeIcon(document) }
                }
                .disabled(isExporting)
                .help(L.string("Export an AppIcon.icon for macOS 15 and later"))

                if isExporting {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.leading, DesignTokens.Spacing.xs)
                }
            }
        }
        .borderTop()
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

            if let url = viewModel.lastExportURL {
                Label(url.path, systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 24)
            }

            if let error = viewModel.lastError {
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

    private func notifyDocumentAvailability() {
        onDocumentAvailabilityChanged?(!viewModel.projectDocuments.isEmpty)
    }

    private func exportSVG(_ document: IconDocument) async {
        guard let directoryURL = pickDirectory(title: L.string("Choose export location for SVG")) else { return }

        isExporting = true
        defer { isExporting = false }

        do {
            let url = directoryURL.appendingPathComponent("\(document.fileSafeName).svg")
            try IconSVGRenderer().render(document: document).write(to: url, atomically: true, encoding: .utf8)
            viewModel.setExportURL(url)
        } catch {
            viewModel.setError(error.localizedDescription)
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
            viewModel.setExportURL(result.iconURL)
        } catch {
            viewModel.setError(error.localizedDescription)
        }
    }

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
