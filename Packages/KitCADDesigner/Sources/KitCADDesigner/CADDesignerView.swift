import AppKit
import SwiftUI
import SceneKit
import UniformTypeIdentifiers

private typealias L = CADDesignerLocalization

public struct CADDesignerView: View {
    @StateObject private var viewModel = CADWorkspaceViewModel()
    @ObservedObject private var store = CADDocumentStore.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let error = store.lastError {
                errorBanner(error)
            }
            ToolBarView(viewModel: viewModel)
            Divider()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onOpenURL { url in
            // Finder “打开方式”或系统文件关联直接打开 `.cadproj` 时，
            // 把 URL 交给当前工作区，而不是丢弃后显示自动创建的空项目。
            viewModel.openProjectURL(url)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .textSelection(.enabled)
            Spacer(minLength: 0)
            Button {
                store.clearError()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .help(L.string("Dismiss"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(Color.orange.opacity(0.12))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "cube.transparent.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(L.string("CAD Designer"))
                    .font(.headline)
                Text(store.selectedDocument?.name ?? L.string("Untitled Project"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                store.createDocument(name: nil)
                viewModel.syncScene()
                viewModel.refreshBOM()
            } label: {
                Label(L.string("New Project"), systemImage: "plus.square")
            }
            .buttonStyle(.bordered)

            Button {
                undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!store.canUndo)
            .help(L.string("Undo"))

            Button {
                redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!store.canRedo)
            .help(L.string("Redo"))

            Button {
                saveDocument()
            } label: {
                Label(L.string("Save"), systemImage: "doc.badge.arrow.up")
            }
            .buttonStyle(.bordered)
            .disabled(store.selectedDocument == nil)

            Button {
                loadDocument()
            } label: {
                Label(L.string("Load"), systemImage: "arrow.down.doc")
            }
            .buttonStyle(.bordered)

            Button {
                exportPNG()
            } label: {
                Label(L.string("Export PNG"), systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.bordered)
            .disabled(store.selectedDocument == nil || viewModel.isExporting)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if store.selectedDocument != nil {
            HSplitView {
                ComponentPaletteView(viewModel: viewModel)
                    .frame(minWidth: 220, idealWidth: 280)

                CADViewportView(viewModel: viewModel)
                    .frame(minWidth: 400, idealWidth: 600)

                VSplitView {
                    PropertyPanelView(viewModel: viewModel)
                        .frame(minHeight: 200)
                    BOMTableView(viewModel: viewModel)
                        .frame(minHeight: 160)
                }
                .frame(minWidth: 280, idealWidth: 340)
            }
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 46))
                .foregroundStyle(.secondary)

            Text(L.string("CAD Designer"))
                .font(.title3.weight(.semibold))

            Text(L.string("Design aluminum profile frames with 3D preview, BOM, and cut optimization."))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)

            Button {
                store.createDocument(name: nil)
                viewModel.syncScene()
            } label: {
                Label(L.string("New Project"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    // MARK: - Actions

    private func undo() {
        viewModel.undo()
    }

    private func redo() {
        viewModel.redo()
    }

    private func saveDocument() {
        guard let document = store.selectedDocument else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.cadDesignerProject]
        panel.nameFieldStringValue = "\(document.name.fileSafeName).cadproj"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        viewModel.saveProject(to: url)
    }

    private func loadDocument() {
        let panel = NSOpenPanel()
        // Native `.cadproj` files must be selectable, while older `.json`
        // exports remain openable.
        panel.allowedContentTypes = [.cadDesignerProject, .json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        viewModel.loadProject(from: url)
    }

    @MainActor
    private func exportPNG() {
        viewModel.isExporting = true
        defer { viewModel.isExporting = false }

        // 通过 NSViewRepresentable 创建的 SCNView 不直接可达，从窗口树查找。
        guard let window = NSApp.windows.first(where: { $0.contentView != nil }),
              let found = findSCNView(in: window.contentView) else {
            store.setError("Viewport not available.")
            return
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiCADDesigner", isDirectory: true)
            .appendingPathComponent("\(store.selectedDocument?.name.fileSafeName ?? "design").png")
        do {
            try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try ScreenshotExporter().exportPNG(from: found, to: outputURL)
            store.setExportURL(outputURL)
        } catch {
            store.setError(error.localizedDescription)
        }
    }

    private func findSCNView(in view: NSView?) -> SCNView? {
        guard let view else { return nil }
        if let scnView = view as? SCNView { return scnView }
        for subview in view.subviews {
            if let found = findSCNView(in: subview) { return found }
        }
        return nil
    }
}

extension UTType {
    /// Native CAD Designer project type: JSON payload with a `.cadproj` extension.
    static let cadDesignerProject = UTType(filenameExtension: "cadproj", conformingTo: .json) ?? .json
}

private extension String {
    var fileSafeName: String {
        let safe = lowercased()
            .replacingOccurrences(of: #"[^a-z0-9_-]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return safe.isEmpty ? "untitled" : safe
    }
}

#Preview("CAD Designer") {
    CADDesignerView()
        .frame(width: 1200, height: 760)
}
