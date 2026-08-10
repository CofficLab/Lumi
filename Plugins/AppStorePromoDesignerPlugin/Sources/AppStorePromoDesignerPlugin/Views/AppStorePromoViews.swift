import AppKit
import AppStorePromoKit
import HTMLPreviewKit
import LumiUI
import SwiftUI

public struct AppStorePromoRailView: View {
    @ObservedObject private var workspace = AppStorePromoWorkspaceStore.shared
    @State private var expandedTaskIDs: Set<String> = []

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(PromoLocalization.string("Promo Tasks")).font(.headline)
                Spacer()
                Text("\(workspace.tasks.count)").font(.caption).foregroundStyle(.secondary)
                Button { workspace.reload() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain)
                    .help(PromoLocalization.string("Refresh"))
            }
            .padding(12)
            Divider()

            if workspace.persistenceDirectory == nil {
                railEmpty(PromoLocalization.string("Plugin storage is unavailable."))
            } else if workspace.tasks.isEmpty {
                railEmpty(PromoLocalization.string("Ask the Agent to create a promotional artwork task."))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(workspace.tasks) { task in
                            taskTree(task)
                        }
                    }
                    .padding(10)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear {
            workspace.reload()
            if let selectedTaskID = workspace.selectedTaskID {
                expandedTaskIDs.insert(selectedTaskID)
            }
        }
        .onChange(of: workspace.selectedTaskID) { _, taskID in
            if let taskID { expandedTaskIDs.insert(taskID) }
        }
    }

    private func taskTree(_ task: AppStorePromoTask) -> some View {
        DisclosureGroup(isExpanded: expansionBinding(for: task.id)) {
            if task.images.isEmpty {
                Text(PromoLocalization.string("No images yet"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 30)
                    .padding(.vertical, 5)
            } else {
                ForEach(task.images.sorted(by: { $0.order < $1.order })) { image in
                    imageRow(image, task: task)
                }
            }
        } label: {
            Button {
                workspace.select(taskID: task.id, imageID: task.images.sorted(by: { $0.order < $1.order }).first?.id)
                expandedTaskIDs.insert(task.id)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.stack")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Text("\(task.images.count) \(PromoLocalization.string("images")) · \(task.deviceFamily.rawValue)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
                .padding(.trailing, 6)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(workspace.selectedTaskID == task.id ? Color.accentColor.opacity(0.12) : .clear)
                )
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(role: .destructive) { workspace.deleteTask(id: task.id) } label: {
                    Label(PromoLocalization.string("Delete Task"), systemImage: "trash")
                }
            }
        }
    }

    private func imageRow(_ image: AppStorePromoImage, task: AppStorePromoTask) -> some View {
        Button { workspace.select(taskID: task.id, imageID: image.id) } label: {
            HStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(image.order + 1)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                Text(image.title).font(.caption).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.leading, 18)
            .padding(.vertical, 6)
            .padding(.trailing, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(workspace.selectedTaskID == task.id && workspace.selectedImageID == image.id ? Color.accentColor.opacity(0.18) : .clear)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) { workspace.deleteImage(taskID: task.id, imageID: image.id) } label: {
                Label(PromoLocalization.string("Delete Image"), systemImage: "trash")
            }
        }
    }

    private func expansionBinding(for taskID: String) -> Binding<Bool> {
        Binding(
            get: { expandedTaskIDs.contains(taskID) },
            set: { isExpanded in
                if isExpanded { expandedTaskIDs.insert(taskID) }
                else { expandedTaskIDs.remove(taskID) }
            }
        )
    }

    private func railEmpty(_ text: String) -> some View {
        VStack(spacing: 9) {
            Image(systemName: "rectangle.stack.badge.plus").font(.title2).foregroundStyle(.secondary)
            Text(text).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(18)
    }
}

public struct AppStorePromoDesignerView: View {
    private enum Mode: String, CaseIterable { case preview, source }

    @ObservedObject private var workspace = AppStorePromoWorkspaceStore.shared
    @State private var mode: Mode = .preview
    @State private var isExporting = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if let resolved = workspace.selectedImage,
               let preset = AppStorePromoDisplaySpec.preset(for: workspace.selectedDisplayType) {
                if mode == .preview {
                    HTMLPreviewView(htmlText: resolved.html, fileURL: resolved.htmlURL, contentSize: preset.cgSize)
                        .id("\(resolved.image.updatedAt.timeIntervalSince1970)-\(preset.displayType)")
                } else {
                    ScrollView([.horizontal, .vertical]) {
                        Text(resolved.html)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(18)
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                }
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { workspace.reload() }
        .alert(PromoLocalization.string("Export Failed"), isPresented: errorBinding) {
            Button("OK", role: .cancel) { workspace.lastError = nil }
        } message: {
            Text(workspace.lastError ?? "")
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Spacer()

            if let task = workspace.selectedImage?.task {
                Picker("Display", selection: $workspace.selectedDisplayType) {
                    ForEach(AppStorePromoDisplaySpec.presets(for: task.deviceFamily)) { preset in
                        Text("\(preset.displayType) · \(preset.width)×\(preset.height)").tag(preset.displayType)
                    }
                }
                .labelsHidden().frame(maxWidth: 260)
            }

            Picker("Mode", selection: $mode) {
                Text(PromoLocalization.string("Preview")).tag(Mode.preview)
                Text(PromoLocalization.string("HTML Source")).tag(Mode.source)
            }
            .pickerStyle(.segmented).frame(width: 190)

            Button { workspace.reload() } label: { Label(PromoLocalization.string("Refresh"), systemImage: "arrow.clockwise") }
            Button { Task { await exportSelectedTask() } } label: {
                Label(PromoLocalization.string("Export"), systemImage: "square.and.arrow.down")
            }
            .disabled(workspace.selectedImage == nil || isExporting)
            if isExporting { ProgressView().controlSize(.small) }
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.stack.badge.plus").font(.system(size: 40)).foregroundStyle(.secondary)
            Text(PromoLocalization.string("Ask the Agent to create a promotional artwork task."))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { workspace.lastError != nil }, set: { if !$0 { workspace.lastError = nil } })
    }

    @MainActor
    private func exportSelectedTask() async {
        guard let selected = workspace.selectedImage,
              let preset = AppStorePromoDisplaySpec.preset(for: workspace.selectedDisplayType) else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = PromoLocalization.string("Export")
        guard panel.runModal() == .OK, let directory = panel.url else { return }

        isExporting = true
        defer { isExporting = false }
        do {
            let task = try workspace.documentStore.readTask(storagePath: workspace.storagePath, taskSlug: selected.task.id)
            for imageMeta in task.images.sorted(by: { $0.order < $1.order }) {
                let image = try workspace.documentStore.readImage(storagePath: workspace.storagePath, taskSlug: task.id, imageSlug: imageMeta.id)
                let report = try workspace.documentStore.lintImage(storagePath: workspace.storagePath, taskSlug: task.id, imageSlug: imageMeta.id)
                guard report.isValid else { throw AppStorePromoStoreError.invalidHTML(report.errors) }
                let data = try await AppStorePromoHTMLExporter.exportPNG(html: image.html, fileURL: image.htmlURL, preset: preset)
                let filename = String(format: "%02d-%@-%@.png", imageMeta.order + 1, imageMeta.id, preset.displayType)
                try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
            }
            workspace.lastExportURL = directory
            workspace.lastError = nil
        } catch {
            workspace.setError(error)
        }
    }
}

public struct AppStorePromoAboutView: View {
    public init() {}
    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.artframe").font(.system(size: 46)).foregroundStyle(.purple)
            Text(PromoLocalization.string("App Store Promo Designer")).font(.title2.weight(.semibold))
            Text(PromoLocalization.string("Agent-generated HTML promotional artwork with exact App Store export sizes."))
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(28).frame(width: 420)
    }
}
