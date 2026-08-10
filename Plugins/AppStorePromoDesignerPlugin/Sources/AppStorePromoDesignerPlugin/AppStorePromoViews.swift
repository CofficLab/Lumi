import AppKit
import AppStorePromoKit
import HTMLPreviewKit
import LumiUI
import SwiftUI

public struct AppStorePromoRailView: View {
    @ObservedObject private var workspace = AppStorePromoWorkspaceStore.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(PromoLocalization.string("Promo Projects")).font(.headline)
                Spacer()
                Button { workspace.reload() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain)
                    .help(PromoLocalization.string("Refresh"))
            }
            .padding(12)
            Divider()

            if workspace.currentProjectPath.isEmpty {
                railEmpty(PromoLocalization.string("No project open"))
            } else if workspace.projects.isEmpty {
                railEmpty(PromoLocalization.string("Ask the Agent to create promotional HTML in the current project."))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(workspace.projects) { project in
                            projectSection(project)
                        }
                    }
                    .padding(10)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear { workspace.reload() }
    }

    private func projectSection(_ project: AppStorePromoProject) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { workspace.select(projectID: project.id, pageID: project.pages.sorted(by: { $0.order < $1.order }).first?.id) } label: {
                HStack {
                    Image(systemName: "photo.stack")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Text("\(project.deviceFamily.rawValue) · \(project.localeIdentifier)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(7)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(workspace.selectedProjectID == project.id ? Color.accentColor.opacity(0.14) : .clear)
                )
            }
            .buttonStyle(.plain)

            ForEach(project.pages.sorted(by: { $0.order < $1.order })) { page in
                Button { workspace.select(projectID: project.id, pageID: page.id) } label: {
                    HStack(spacing: 7) {
                        Text("\(page.order + 1)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        Text(page.title).font(.caption).lineLimit(1)
                        Spacer()
                    }
                    .padding(.leading, 24).padding(.vertical, 5).padding(.trailing, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(workspace.selectedPageID == page.id ? Color.accentColor.opacity(0.12) : .clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func railEmpty(_ text: String) -> some View {
        VStack(spacing: 9) {
            Image(systemName: "photo.badge.plus").font(.title2).foregroundStyle(.secondary)
            Text(text).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(18)
    }
}

public struct AppStorePromoDesignerView: View {
    @ObservedObject private var workspace = AppStorePromoWorkspaceStore.shared
    @State private var isExporting = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if let resolved = workspace.selectedPage,
               let preset = AppStorePromoDisplaySpec.preset(for: workspace.selectedDisplayType) {
                HTMLPreviewView(
                    htmlText: resolved.html,
                    fileURL: resolved.htmlURL,
                    contentSize: preset.cgSize
                )
                .id("\(resolved.page.updatedAt.timeIntervalSince1970)-\(preset.displayType)")
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { workspace.reload() }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "photo.artframe").foregroundStyle(.purple)
            VStack(alignment: .leading, spacing: 1) {
                Text(PromoLocalization.string("App Store Promo Designer")).font(.headline)
                if let page = workspace.selectedPage { Text(page.page.title).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()

            if let project = workspace.selectedPage?.project {
                Picker("Display", selection: $workspace.selectedDisplayType) {
                    ForEach(AppStorePromoDisplaySpec.presets(for: project.deviceFamily)) { preset in
                        Text("\(preset.displayType) · \(preset.width)×\(preset.height)").tag(preset.displayType)
                    }
                }
                .labelsHidden().frame(maxWidth: 260)
            }

            Button { workspace.reload() } label: { Label(PromoLocalization.string("Refresh"), systemImage: "arrow.clockwise") }
            Button { Task { await exportSelected() } } label: { Label(PromoLocalization.string("Export PNG"), systemImage: "square.and.arrow.down") }
                .disabled(workspace.selectedPage == nil || isExporting)
            if isExporting { ProgressView().controlSize(.small) }
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.stack").font(.system(size: 40)).foregroundStyle(.secondary)
            Text(PromoLocalization.string("Ask the Agent to create promotional HTML in the current project."))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @MainActor
    private func exportSelected() async {
        guard let page = workspace.selectedPage,
              let preset = AppStorePromoDisplaySpec.preset(for: workspace.selectedDisplayType) else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let directory = panel.url else { return }
        isExporting = true
        defer { isExporting = false }
        do {
            let data = try await AppStorePromoHTMLExporter.exportPNG(
                html: page.html,
                fileURL: page.htmlURL,
                preset: preset
            )
            let url = directory.appendingPathComponent("\(page.page.order + 1)-\(page.page.id)-\(preset.displayType).png")
            try data.write(to: url, options: .atomic)
            workspace.lastExportURL = url
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
