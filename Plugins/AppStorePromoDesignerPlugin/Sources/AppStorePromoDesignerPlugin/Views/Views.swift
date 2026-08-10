import AppKit
import AppStorePromoKit
import HTMLPreviewKit
import LumiUI
import SwiftUI

public struct PromoRailView: View {
    @ObservedObject private var workspace = WorkspaceStore.shared
    @State private var expandedTaskIDs: Set<String> = []
    @State private var expandedScopes: Set<Scope> = [.project, .app]

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(PromoLocalization.string("Promo Tasks")).font(.headline)
                Spacer()
                Text("\(totalTaskCount)").font(.caption).foregroundStyle(.secondary)
                Button { workspace.reload() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain)
                    .help(PromoLocalization.string("Refresh"))
            }
            .padding(12)
            Divider()

            if workspace.appStorageDirectory == nil {
                railEmpty(PromoLocalization.string("Plugin storage is unavailable."))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        scopeSection(.project)
                        scopeSection(.app)
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

    private var totalTaskCount: Int {
        workspace.projectTasks.count + workspace.appTasks.count
    }

    @ViewBuilder
    private func scopeSection(_ scope: Scope) -> some View {
        let tasks = workspace.tasks(for: scope)
        let isUnavailable = (scope == .project && workspace.currentProjectPath == nil)
        let title = scope == .project
            ? PromoLocalization.string("In Project")
            : PromoLocalization.string("In App")
        let subtitle: String = {
            if scope == .project, let path = workspace.currentProjectPath {
                let name = URL(fileURLWithPath: path).lastPathComponent
                return "· \(name)"
            }
            return ""
        }()
        VStack(alignment: .leading, spacing: 6) {
            DisclosureGroup(isExpanded: scopeBinding(scope)) {
                if isUnavailable {
                    scopeEmpty(PromoLocalization.string("Open a project to enable project-local storage."))
                } else if tasks.isEmpty {
                    scopeEmpty(PromoLocalization.string("Ask the Agent to create a promotional artwork task."))
                } else {
                    ForEach(tasks) { task in
                        taskTree(task, scope: scope)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: scope == .project ? "folder" : "app.badge")
                        .font(.caption)
                        .foregroundStyle(scope == .project ? Color.accentColor : .secondary)
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(tasks.count)").font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
        }
    }

    private func taskTree(_ task: AppStorePromoTask, scope: Scope) -> some View {
        DisclosureGroup(isExpanded: expansionBinding(for: task.id)) {
            if task.images.isEmpty {
                Text(PromoLocalization.string("No images yet"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 30)
                    .padding(.vertical, 5)
            } else {
                ForEach(task.images.sorted(by: { $0.order < $1.order })) { image in
                    imageRow(image, task: task, scope: scope)
                }
            }
        } label: {
            Button {
                workspace.selectScope(scope, taskID: task.id, imageID: task.images.sorted(by: { $0.order < $1.order }).first?.id)
                expandedTaskIDs.insert(task.id)
                expandedScopes.insert(scope)
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
                        .fill(workspace.selectedScope == scope && workspace.selectedTaskID == task.id ? Color.accentColor.opacity(0.12) : .clear)
                )
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(role: .destructive) { workspace.deleteTask(scope: scope, id: task.id) } label: {
                    Label(PromoLocalization.string("Delete Task"), systemImage: "trash")
                }
            }
        }
    }

    private func imageRow(_ image: AppStorePromoImage, task: AppStorePromoTask, scope: Scope) -> some View {
        Button { workspace.selectScope(scope, taskID: task.id, imageID: image.id) } label: {
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
                    .fill(workspace.selectedScope == scope && workspace.selectedTaskID == task.id && workspace.selectedImageID == image.id ? Color.accentColor.opacity(0.18) : .clear)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) { workspace.deleteImage(scope: scope, taskID: task.id, imageID: image.id) } label: {
                Label(PromoLocalization.string("Delete Image"), systemImage: "trash")
            }
        }
    }

    private func scopeBinding(_ scope: Scope) -> Binding<Bool> {
        Binding(
            get: { expandedScopes.contains(scope) },
            set: { isExpanded in
                if isExpanded { expandedScopes.insert(scope) }
                else { expandedScopes.remove(scope) }
            }
        )
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

    private func scopeEmpty(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.leading, 18)
            .padding(.vertical, 6)
    }

    private func railEmpty(_ text: String) -> some View {
        VStack(spacing: 9) {
            Image(systemName: "rectangle.stack.badge.plus").font(.title2).foregroundStyle(.secondary)
            Text(text).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(18)
    }
}

public struct PromoDesignerView: View {
    private enum Mode: String, CaseIterable { case preview, source }

    @ObservedObject private var workspace = WorkspaceStore.shared
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
            if let task = workspace.selectedImage?.task {
                scopeBadge
                Text(task.title).font(.subheadline.weight(.semibold)).lineLimit(1)
            }
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

    private var scopeBadge: some View {
        let title = workspace.selectedScope == .project
            ? PromoLocalization.string("In Project")
            : PromoLocalization.string("In App")
        return HStack(spacing: 4) {
            Image(systemName: workspace.selectedScope == .project ? "folder" : "app.badge")
                .font(.caption2)
            Text(title).font(.caption2)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
        )
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
            let storagePath = workspace.storagePath(for: workspace.selectedScope)
            let task = try workspace.documentStore.readTask(storagePath: storagePath, taskSlug: selected.task.id)
            let scopeSubdir = workspace.selectedScope == .project ? "project" : "app"
            let targetDirectory = directory.appendingPathComponent(scopeSubdir, isDirectory: true)
            try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
            for imageMeta in task.images.sorted(by: { $0.order < $1.order }) {
                let image = try workspace.documentStore.readImage(storagePath: storagePath, taskSlug: task.id, imageSlug: imageMeta.id)
                let report = try workspace.documentStore.lintImage(storagePath: storagePath, taskSlug: task.id, imageSlug: imageMeta.id)
                guard report.isValid else { throw AppStorePromoStoreError.invalidHTML(report.errors) }
                let data = try await AppStorePromoHTMLExporter.exportPNG(html: image.html, fileURL: image.htmlURL, preset: preset)
                let filename = String(format: "%02d-%@-%@.png", imageMeta.order + 1, imageMeta.id, preset.displayType)
                try data.write(to: targetDirectory.appendingPathComponent(filename), options: .atomic)
            }
            workspace.lastExportURL = targetDirectory
            workspace.lastError = nil
        } catch {
            workspace.setError(error)
        }
    }
}

public struct PromoAboutView: View {
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