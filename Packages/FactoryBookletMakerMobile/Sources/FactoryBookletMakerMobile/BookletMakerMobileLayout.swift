import BookletMakerPlugin
import KernelLumi
import SwiftUI
import UniformTypeIdentifiers

/// BookletMaker 专属的 iOS 布局。Factory 拥有导航、文件导入、Sheet 和
/// size-class 适配；PDF 界面与业务操作由 `BookletMakerMobileFeature` 提供。
struct BookletMakerMobileLayout: View {
    @ObservedObject var kernel: KernelLumi
    @StateObject private var feature = BookletMakerMobileFeature()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isImporterPresented = false
    @State private var isSettingsPresented = false

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.pdf]) { result in
            if case .success(let url) = result {
                Task { await feature.loadPDF(url) }
            }
        }
    }

    // MARK: - iPhone

    private var compactLayout: some View {
        NavigationStack {
            VStack(spacing: 0) {
                toolPicker
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                Divider()
                feature.makeContentView()
            }
            .navigationTitle(feature.documentName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { documentToolbar }
            .safeAreaInset(edge: .bottom, spacing: 0) { compactActionBar }
            .sheet(isPresented: $isSettingsPresented) { settingsSheet }
        }
    }

    private var compactActionBar: some View {
        VStack(spacing: 10) {
            statusRow
            HStack(spacing: 12) {
                Button {
                    isSettingsPresented = true
                } label: {
                    Label(BookletLocalization.string("Settings"),
                          systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                primaryActionButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private var settingsSheet: some View {
        NavigationStack {
            ScrollView {
                feature.makeSettingsView()
                    .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(BookletLocalization.string("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(BookletLocalization.string("Done")) { isSettingsPresented = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - iPad

    private var regularLayout: some View {
        NavigationSplitView {
            List {
                Section {
                    documentCard
                }
                Section(BookletLocalization.string("PDF Tools")) {
                    ForEach(BookletMakerMobileFeature.Tool.allCases) { tool in
                        Button {
                            feature.selectedTool = tool
                        } label: {
                            HStack {
                                Label(tool.title, systemImage: tool.systemImage)
                                Spacer()
                                if feature.selectedTool == tool {
                                    Image(systemName: "checkmark")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.tint)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(BookletLocalization.string("Booklet Maker"))
            .toolbar { documentToolbar }
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 300)
        } content: {
            NavigationStack {
                feature.makeContentView()
                    .navigationTitle(feature.selectedTool.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .safeAreaInset(edge: .bottom, spacing: 0) { regularActionBar }
            }
            .navigationSplitViewColumnWidth(min: 430, ideal: 650)
        } detail: {
            NavigationStack {
                ScrollView {
                    feature.makeSettingsView()
                        .padding(16)
                }
                .background(Color(uiColor: .systemGroupedBackground))
                .navigationTitle(BookletLocalization.string("Settings"))
                .navigationBarTitleDisplayMode(.inline)
            }
            .navigationSplitViewColumnWidth(min: 280, ideal: 330, max: 390)
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var documentCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(feature.documentName, systemImage: "doc.fill")
                .font(.headline)
                .lineLimit(2)
            Text(BookletLocalization.string("%lld pages", Int64(feature.pageCount)))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(BookletLocalization.string("Choose Another PDF")) { isImporterPresented = true }
                .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 4)
    }

    private var regularActionBar: some View {
        HStack(spacing: 16) {
            statusRow
            Spacer()
            primaryActionButton
                .frame(maxWidth: 280)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: - Shared controls

    private var toolPicker: some View {
        Picker(BookletLocalization.string("PDF Tools"), selection: toolBinding) {
            ForEach(BookletMakerMobileFeature.Tool.allCases) { tool in
                Label(tool.title, systemImage: tool.systemImage).tag(tool)
            }
        }
        .pickerStyle(.segmented)
    }

    private var toolBinding: Binding<BookletMakerMobileFeature.Tool> {
        Binding(get: { feature.selectedTool }, set: { feature.selectedTool = $0 })
    }

    @ToolbarContentBuilder
    private var documentToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button(BookletLocalization.string("Choose PDF"), systemImage: "doc.badge.plus") {
                    isImporterPresented = true
                }
                if !feature.isDemo {
                    Button(BookletLocalization.string("Return to Sample"),
                           systemImage: "arrow.uturn.backward") {
                        feature.clearDocument()
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel(BookletLocalization.string("Document Actions"))
        }
    }

    private var statusRow: some View {
        Group {
            if feature.isWorking {
                HStack(spacing: 8) {
                    ProgressView(value: feature.progress)
                        .frame(maxWidth: 120)
                    Text(BookletLocalization.string("Progress percent %lld", Int64(feature.progress * 100)))
                    Button(BookletLocalization.string("Cancel")) { feature.cancel() }
                }
            } else if let error = feature.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            } else {
                Label(feature.outputSummary, systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.footnote)
    }

    private var primaryActionButton: some View {
        Button {
            feature.export()
        } label: {
            Label(exportTitle, systemImage: "square.and.arrow.up")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!feature.canExport || feature.isWorking)
    }

    private var exportTitle: String {
        switch feature.selectedTool {
        case .split: BookletLocalization.string("Export PDFs")
        case .booklet: BookletLocalization.string("Export Booklet")
        }
    }
}
