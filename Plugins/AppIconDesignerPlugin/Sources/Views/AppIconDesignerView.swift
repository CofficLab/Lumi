import AppKit
import SwiftUI
import UniformTypeIdentifiers

private typealias L = AppIconDesignerLocalization

public struct AppIconDesignerView: View {
    @StateObject private var viewModel = AppIconDesignerViewModel()
    @ObservedObject private var store = AppIconArtifactStore.shared
    @ObservedObject private var documentStore = IconDocumentStore.shared
    @State private var backgroundHex = "#111827"
    @State private var selectedLayerId: String?
    @State private var selectedFillHex = "#38bdf8"
    @State private var translateX = 0.0
    @State private var translateY = 0.0
    @State private var layerScale = 1.0
    @State private var rotationDegrees = 0.0
    @State private var isExportingSVG = false
    @State private var symbolName = "sparkles"
    @State private var textValue = "L"
    @State private var shadowColor = "#00000040"
    @State private var shadowRadius = 0.0
    @State private var shadowY = 12.0
    @State private var blurRadius = 0.0
    @State private var layerName = ""
    @State private var layerOpacity = 1.0
    @State private var shapeX = 0.0
    @State private var shapeY = 0.0
    @State private var shapeWidth = 512.0
    @State private var shapeHeight = 512.0
    @State private var shapeCornerRadius = 0.0
    @State private var circleCX = 512.0
    @State private var circleCY = 512.0
    @State private var circleRadius = 256.0
    @State private var lineX1 = 256.0
    @State private var lineY1 = 512.0
    @State private var lineX2 = 768.0
    @State private var lineY2 = 512.0
    @State private var shapeSize = 420.0
    @State private var shapeWeight = "regular"
    @State private var lintIssues: [IconDocumentLintIssue] = []

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "app.dashed")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(L.string("App Icon Designer"))
                    .font(.headline)
                Text(L.string("Create vector icons with shape, color, layer, and export tools."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if documentStore.selectedDocument != nil {
                Button {
                    undoDocumentChange()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!documentStore.canUndo)
                .help(L.string("Undo"))

                Button {
                    redoDocumentChange()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!documentStore.canRedo)
                .help(L.string("Redo"))

                Button {
                    saveCurrentDocument()
                } label: {
                    Image(systemName: "doc.badge.arrow.up")
                }
                .help(L.string("Save document JSON"))
            }

            Button {
                loadDocument()
            } label: {
                Image(systemName: "arrow.down.doc")
            }
            .help(L.string("Load document JSON"))

            Button {
                Task { await exportCurrentDesign() }
            } label: {
                Label(L.string("Export"), systemImage: "square.and.arrow.down")
            }
            .disabled((viewModel.selectedArtifact == nil && documentStore.selectedDocument == nil) || viewModel.isExporting || isExportingSVG)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if let document = documentStore.selectedDocument {
            HSplitView {
                documentPreviewPane(document: document)
                    .frame(minWidth: 360, idealWidth: 560)

                inspectorPane(document: document)
                    .frame(minWidth: 220, idealWidth: 260)
            }
            .onAppear {
                syncInspectorSelection(document: document)
            }
            .onChange(of: document.id) { _, _ in
                syncInspectorSelection(document: document)
            }
            .onChange(of: document.layers) { _, _ in
                syncInspectorSelection(document: document)
            }
        } else if let artifact = viewModel.selectedArtifact {
            HSplitView {
                previewPane(artifact: artifact)
                    .frame(minWidth: 360, idealWidth: 560)

                candidatesPane
                    .frame(minWidth: 220, idealWidth: 260)
            }
        } else {
            emptyState
        }
    }

    private func previewPane(artifact: AppIconArtifact) -> some View {
        VStack(spacing: 18) {
            Spacer(minLength: 16)

            AppIconImageView(path: artifact.sourcePath)
                .frame(width: 256, height: 256)
                .clipShape(RoundedRectangle(cornerRadius: 56, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 22, y: 12)

            VStack(spacing: 5) {
                Text(artifact.title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text(artifact.sourcePath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 24)

            sizeStrip(artifact: artifact)

            exportControls

            if let lastExportURL = store.lastExportURL {
                Label(lastExportURL.path, systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 24)
            }

            if let lastError = store.lastError {
                Label(lastError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                    .padding(.horizontal, 24)
            }

            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sizeStrip(artifact: AppIconArtifact) -> some View {
        HStack(alignment: .bottom, spacing: 16) {
            iconSample(path: artifact.sourcePath, size: 96, label: "96")
            iconSample(path: artifact.sourcePath, size: 64, label: "64")
            iconSample(path: artifact.sourcePath, size: 32, label: "32")
            iconSample(path: artifact.sourcePath, size: 16, label: "16")
        }
        .padding(.top, 8)
    }

    private func iconSample(path: String, size: CGFloat, label: String) -> some View {
        VStack(spacing: 6) {
            AppIconImageView(path: path)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: max(4, size * 0.22), style: .continuous))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 104)
    }

    private var exportControls: some View {
        HStack(spacing: 8) {
            TextField(L.string("Output directory"), text: $viewModel.exportDirectory)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 420)

            Button {
                Task { await viewModel.exportSelected() }
            } label: {
                if viewModel.isExporting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "square.and.arrow.down")
                }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.selectedArtifact == nil || viewModel.isExporting)
            .help(L.string("Export AppIcon.appiconset"))
        }
        .padding(.horizontal, 24)
    }

    private var candidatesPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L.string("Candidates"))
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(store.artifacts) { artifact in
                        candidateRow(artifact)
                    }
                }
                .padding(12)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func inspectorPane(document: IconDocument) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L.string("Inspector"))
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    presetSection
                    canvasSection(document: document)
                    addShapeSection
                    layersSection(document: document)
                    selectedLayerSection(document: document)
                    exportDocumentSection
                }
                .padding(12)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func canvasSection(document: IconDocument) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.string("Canvas"))
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 8) {
                TextField(L.string("Background"), text: $backgroundHex)
                    .textFieldStyle(.roundedBorder)

                Button {
                    applyBackground()
                } label: {
                    Image(systemName: "paintbucket")
                }
                .help(L.string("Apply background color"))
            }

            HStack(spacing: 8) {
                Button {
                    applyGradientBackground()
                } label: {
                    Image(systemName: "paintpalette")
                }
                .help(L.string("Apply gradient background"))

                Button {
                    applyRadialBackground()
                } label: {
                    Image(systemName: "circle.hexagongrid.fill")
                }
                .help(L.string("Apply radial background"))
            }

            Text("\(Int(document.width)) x \(Int(document.height))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.string("Presets"))
                .font(.subheadline.weight(.semibold))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                ForEach(IconPresetLibrary.all) { preset in
                    presetButton(preset, compact: true)
                }
            }
        }
    }

    private var addShapeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.string("Add"))
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 8) {
                shapeButton("rectangle", icon: "rectangle")
                shapeButton("circle", icon: "circle")
                shapeButton("capsule", icon: "capsule")
                shapeButton("triangle", icon: "triangle")
                shapeButton("line", icon: "line.diagonal")
            }

            HStack(spacing: 8) {
                TextField(L.string("SF Symbol"), text: $symbolName)
                    .textFieldStyle(.roundedBorder)
                Button {
                    addShape("symbol")
                } label: {
                    Image(systemName: "sparkles")
                }
                .help(L.string("Add SF Symbol"))
            }

            HStack(spacing: 8) {
                TextField(L.string("Text"), text: $textValue)
                    .textFieldStyle(.roundedBorder)
                Button {
                    addShape("text")
                } label: {
                    Image(systemName: "textformat")
                }
                .help(L.string("Add text"))
            }
        }
    }

    private func shapeButton(_ shape: String, icon: String) -> some View {
        Button {
            addShape(shape)
        } label: {
            Image(systemName: icon)
                .frame(width: 24, height: 24)
        }
        .help(L.format("Add %@", L.string(shape)))
    }

    private func layersSection(document: IconDocument) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.string("Layers"))
                .font(.subheadline.weight(.semibold))

            if document.layers.isEmpty {
                Text(L.string("No layers"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(document.layers.reversed()) { layer in
                        layerRow(layer)
                    }
                }
            }
        }
    }

    private func selectedLayerSection(document: IconDocument) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.string("Layer"))
                .font(.subheadline.weight(.semibold))

            if selectedLayer(document: document) == nil {
                Text(L.string("Select a layer to edit it."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let layer = selectedLayer(document: document) {
                HStack(spacing: 8) {
                    TextField(L.string("Name"), text: $layerName)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        applySelectedLayerName()
                    } label: {
                        Image(systemName: "text.cursor")
                    }
                    .help(L.string("Rename layer"))
                }

                HStack(spacing: 8) {
                    TextField(L.string("Fill"), text: $selectedFillHex)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        applySelectedLayerStyle()
                    } label: {
                        Image(systemName: "eyedropper")
                    }
                    .help(L.string("Apply fill color"))
                }

                selectedLayerShapeSection(layer: layer)

                VStack(spacing: 8) {
                    Stepper(value: $layerOpacity, in: 0...1, step: 0.05) {
                        Text(L.format("Opacity %.2f", layerOpacity))
                            .font(.caption)
                    }
                    Stepper(value: $translateX, in: -1024...1024, step: 8) {
                        Text(L.format("X %d", Int(translateX)))
                            .font(.caption)
                    }
                    Stepper(value: $translateY, in: -1024...1024, step: 8) {
                        Text(L.format("Y %d", Int(translateY)))
                            .font(.caption)
                    }
                    Stepper(value: $layerScale, in: 0.1...4, step: 0.1) {
                        Text(L.format("Scale %.1f", layerScale))
                            .font(.caption)
                    }
                    Stepper(value: $rotationDegrees, in: -360...360, step: 5) {
                        Text(L.format("Rotate %d", Int(rotationDegrees)))
                            .font(.caption)
                    }
                    HStack(spacing: 8) {
                        TextField(L.string("Shadow"), text: $shadowColor)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            applySelectedLayerEffects()
                        } label: {
                            Image(systemName: "square.3.layers.3d")
                        }
                        .help(L.string("Apply shadow color"))
                    }
                    Stepper(value: $shadowRadius, in: 0...160, step: 4) {
                        Text(L.format("Shadow %d", Int(shadowRadius)))
                            .font(.caption)
                    }
                    Stepper(value: $shadowY, in: -160...160, step: 4) {
                        Text(L.format("Shadow Y %d", Int(shadowY)))
                            .font(.caption)
                    }
                    Stepper(value: $blurRadius, in: 0...80, step: 2) {
                        Text(L.format("Blur %d", Int(blurRadius)))
                            .font(.caption)
                    }
                }
                .onChange(of: translateX) { _, _ in applySelectedLayerTransform() }
                .onChange(of: translateY) { _, _ in applySelectedLayerTransform() }
                .onChange(of: layerScale) { _, _ in applySelectedLayerTransform() }
                .onChange(of: rotationDegrees) { _, _ in applySelectedLayerTransform() }
                .onChange(of: layerOpacity) { _, _ in applySelectedLayerStyle() }
                .onChange(of: shadowRadius) { _, _ in applySelectedLayerEffects() }
                .onChange(of: shadowY) { _, _ in applySelectedLayerEffects() }
                .onChange(of: blurRadius) { _, _ in applySelectedLayerEffects() }
            }
        }
    }

    @ViewBuilder
    private func selectedLayerShapeSection(layer: IconLayer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.string("Geometry"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            switch layer.shape {
            case .rectangle:
                rectLikeControls(showCornerRadius: true)
            case .capsule, .triangle:
                rectLikeControls(showCornerRadius: false)
            case .circle:
                Stepper(value: $circleCX, in: -1024...2048, step: 8) {
                    Text(L.format("Center X %d", Int(circleCX))).font(.caption)
                }
                Stepper(value: $circleCY, in: -1024...2048, step: 8) {
                    Text(L.format("Center Y %d", Int(circleCY))).font(.caption)
                }
                Stepper(value: $circleRadius, in: 1...2048, step: 8) {
                    Text(L.format("Radius %d", Int(circleRadius))).font(.caption)
                }
            case .line:
                Stepper(value: $lineX1, in: -1024...2048, step: 8) {
                    Text(L.format("X1 %d", Int(lineX1))).font(.caption)
                }
                Stepper(value: $lineY1, in: -1024...2048, step: 8) {
                    Text(L.format("Y1 %d", Int(lineY1))).font(.caption)
                }
                Stepper(value: $lineX2, in: -1024...2048, step: 8) {
                    Text(L.format("X2 %d", Int(lineX2))).font(.caption)
                }
                Stepper(value: $lineY2, in: -1024...2048, step: 8) {
                    Text(L.format("Y2 %d", Int(lineY2))).font(.caption)
                }
            case .symbol:
                HStack(spacing: 8) {
                    TextField(L.string("Symbol"), text: $symbolName)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        applySelectedLayerShape()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .help(L.string("Apply symbol name"))
                }
                sizeAndWeightControls()
            case .text:
                HStack(spacing: 8) {
                    TextField(L.string("Text"), text: $textValue)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        applySelectedLayerShape()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .help(L.string("Apply text"))
                }
                sizeAndWeightControls()
            }
        }
        .onChange(of: shapeX) { _, _ in applySelectedLayerShape() }
        .onChange(of: shapeY) { _, _ in applySelectedLayerShape() }
        .onChange(of: shapeWidth) { _, _ in applySelectedLayerShape() }
        .onChange(of: shapeHeight) { _, _ in applySelectedLayerShape() }
        .onChange(of: shapeCornerRadius) { _, _ in applySelectedLayerShape() }
        .onChange(of: circleCX) { _, _ in applySelectedLayerShape() }
        .onChange(of: circleCY) { _, _ in applySelectedLayerShape() }
        .onChange(of: circleRadius) { _, _ in applySelectedLayerShape() }
        .onChange(of: lineX1) { _, _ in applySelectedLayerShape() }
        .onChange(of: lineY1) { _, _ in applySelectedLayerShape() }
        .onChange(of: lineX2) { _, _ in applySelectedLayerShape() }
        .onChange(of: lineY2) { _, _ in applySelectedLayerShape() }
        .onChange(of: shapeSize) { _, _ in applySelectedLayerShape() }
        .onChange(of: shapeWeight) { _, _ in applySelectedLayerShape() }
    }

    private func rectLikeControls(showCornerRadius: Bool) -> some View {
        Group {
            Stepper(value: $shapeX, in: -1024...2048, step: 8) {
                Text(L.format("X %d", Int(shapeX))).font(.caption)
            }
            Stepper(value: $shapeY, in: -1024...2048, step: 8) {
                Text(L.format("Y %d", Int(shapeY))).font(.caption)
            }
            Stepper(value: $shapeWidth, in: 1...2048, step: 8) {
                Text(L.format("Width %d", Int(shapeWidth))).font(.caption)
            }
            Stepper(value: $shapeHeight, in: 1...2048, step: 8) {
                Text(L.format("Height %d", Int(shapeHeight))).font(.caption)
            }
            if showCornerRadius {
                Stepper(value: $shapeCornerRadius, in: 0...512, step: 8) {
                    Text(L.format("Radius %d", Int(shapeCornerRadius))).font(.caption)
                }
            }
        }
    }

    private func sizeAndWeightControls() -> some View {
        Group {
            Stepper(value: $shapeX, in: -1024...2048, step: 8) {
                Text(L.format("X %d", Int(shapeX))).font(.caption)
            }
            Stepper(value: $shapeY, in: -1024...2048, step: 8) {
                Text(L.format("Y %d", Int(shapeY))).font(.caption)
            }
            Stepper(value: $shapeSize, in: 1...2048, step: 8) {
                Text(L.format("Size %d", Int(shapeSize))).font(.caption)
            }
            Picker(L.string("Weight"), selection: $shapeWeight) {
                Text(L.string("Regular")).tag("regular")
                Text(L.string("Medium")).tag("medium")
                Text(L.string("Semibold")).tag("semibold")
                Text(L.string("Bold")).tag("bold")
                Text(L.string("Heavy")).tag("heavy")
            }
            .font(.caption)
        }
    }

    private var exportDocumentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.string("Export"))
                .font(.subheadline.weight(.semibold))

            Button {
                Task { await exportCurrentDesign() }
            } label: {
                if isExportingSVG {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label(L.string("Export SVG"), systemImage: "square.and.arrow.down")
                }
            }
            .disabled(documentStore.selectedDocument == nil || isExportingSVG)

            Button {
                refreshLintIssues()
            } label: {
                Label(L.string("Check Quality"), systemImage: "checkmark.seal")
            }
            .disabled(documentStore.selectedDocument == nil || isExportingSVG)

            if !lintIssues.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(lintIssues.enumerated()), id: \.offset) { _, issue in
                        Label(issue.message, systemImage: issue.severity == .error ? "xmark.octagon" : "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(issue.severity == .error ? .red : .orange)
                            .lineLimit(3)
                    }
                }
                .padding(8)
                .background(rowBackground(isSelected: false))
            }

            Button {
                Task { await exportCurrentDocumentAppIconSet() }
            } label: {
                Label(L.string("Export AppIcon Set"), systemImage: "app.dashed")
            }
            .disabled(documentStore.selectedDocument == nil || isExportingSVG)

            Button {
                saveCurrentDocument()
            } label: {
                Label(L.string("Save Document"), systemImage: "doc.badge.arrow.up")
            }
            .disabled(documentStore.selectedDocument == nil || isExportingSVG)

            Button {
                loadDocument()
            } label: {
                Label(L.string("Load Document"), systemImage: "arrow.down.doc")
            }
            .disabled(isExportingSVG)
        }
    }

    private func documentPreviewPane(document: IconDocument) -> some View {
        VStack(spacing: 18) {
            Spacer(minLength: 16)

            IconRenderedDocumentView(document: document)
                .frame(width: 256, height: 256)
                .clipShape(RoundedRectangle(cornerRadius: 56, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 22, y: 12)

            VStack(spacing: 5) {
                Text(document.title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text(L.format("%d x %d vector document", Int(document.width), Int(document.height)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)

            documentSizeStrip(document: document)

            if let lastExportURL = documentStore.lastExportURL {
                Label(lastExportURL.path, systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 24)
            }

            if let lastError = documentStore.lastError {
                Label(lastError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                    .padding(.horizontal, 24)
            }

            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func documentSizeStrip(document: IconDocument) -> some View {
        HStack(alignment: .bottom, spacing: 16) {
            documentIconSample(document: document, size: 96, label: "96")
            documentIconSample(document: document, size: 64, label: "64")
            documentIconSample(document: document, size: 32, label: "32")
            documentIconSample(document: document, size: 16, label: "16")
        }
        .padding(.top, 8)
    }

    private func documentIconSample(document: IconDocument, size: CGFloat, label: String) -> some View {
        VStack(spacing: 6) {
            IconRenderedDocumentView(document: document)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: max(4, size * 0.22), style: .continuous))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 104)
    }

    private func iconName(for shape: IconShape) -> String {
        switch shape {
        case .rectangle:
            return "rectangle"
        case .circle:
            return "circle"
        case .capsule:
            return "capsule"
        case .triangle:
            return "triangle"
        case .line:
            return "line.diagonal"
        case .symbol:
            return "sparkles"
        case .text:
            return "textformat"
        }
    }

    private func layerRow(_ layer: IconLayer) -> some View {
        HStack(spacing: 10) {
            Image(systemName: iconName(for: layer.shape))
                .frame(width: 22)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(layer.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(layer.id)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)

            HStack(spacing: 2) {
                iconActionButton("arrow.down", help: L.string("Move backward")) {
                    moveLayer(layer, direction: .backward)
                }
                iconActionButton("arrow.up", help: L.string("Move forward")) {
                    moveLayer(layer, direction: .forward)
                }
                iconActionButton("plus.square.on.square", help: L.string("Duplicate")) {
                    duplicateLayer(layer)
                }
                iconActionButton("trash", help: L.string("Delete"), role: .destructive) {
                    deleteLayer(layer)
                }
            }
        }
        .padding(8)
        .background(rowBackground(isSelected: selectedLayerId == layer.id))
        .contentShape(Rectangle())
        .onTapGesture {
            selectLayer(layer)
        }
    }

    private func iconActionButton(
        _ icon: String,
        help: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role) {
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.borderless)
        .help(help)
    }

    private func candidateRow(_ artifact: AppIconArtifact) -> some View {
        Button {
            store.selectArtifact(id: artifact.id)
        } label: {
            HStack(spacing: 10) {
                AppIconImageView(path: artifact.sourcePath)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(artifact.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(artifact.createdAt, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(8)
            .background(rowBackground(isSelected: store.selectedArtifactId == artifact.id))
        }
        .buttonStyle(.plain)
    }

    private func rowBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(isSelected ? Color.accentColor.opacity(0.14) : Color(nsColor: .windowBackgroundColor))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.38) : Color.black.opacity(0.06), lineWidth: 1)
            }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 46))
                .foregroundStyle(.secondary)

            Text(L.string("Choose a starting point"))
                .font(.title3.weight(.semibold))

            Text(L.string("Start from a tuned preset or create a blank vector canvas."))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(IconPresetLibrary.all) { preset in
                    presetButton(preset, compact: false)
                }
            }
            .frame(maxWidth: 620)

            Button {
                createBlankDocument()
            } label: {
                Label(L.string("Blank Icon"), systemImage: "plus")
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private func presetButton(_ preset: IconPreset, compact: Bool) -> some View {
        Button {
            applyPreset(preset)
        } label: {
            if compact {
                VStack(spacing: 6) {
                    IconRenderedDocumentView(document: preset.makeDocument(nil))
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Text(localizedTitle(for: preset))
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(rowBackground(isSelected: false))
            } else {
                HStack(spacing: 10) {
                    IconRenderedDocumentView(document: preset.makeDocument(nil))
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(localizedTitle(for: preset))
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(localizedSubtitle(for: preset))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(rowBackground(isSelected: false))
            }
        }
        .buttonStyle(.plain)
        .help(L.format("Apply %@", localizedTitle(for: preset)))
    }

    private func localizedTitle(for preset: IconPreset) -> String {
        L.string(preset.title)
    }

    private func localizedSubtitle(for preset: IconPreset) -> String {
        L.string(preset.subtitle)
    }

    private func createBlankDocument() {
        let document = documentStore.createDocument(
            title: L.string("Untitled Icon"),
            width: 1024,
            height: 1024,
            background: .color(backgroundHex)
        )
        selectedLayerId = document.layers.first?.id
    }

    private func applyPreset(_ preset: IconPreset) {
        let document = documentStore.createDocument(from: preset)
        selectedLayerId = document.layers.last?.id
        syncInspectorSelection(document: document)
    }

    private func applyBackground() {
        do {
            _ = try documentStore.updateSelectedDocument { document in
                document.background = .color(backgroundHex)
            }
        } catch {
            documentStore.setError(error.localizedDescription)
        }
    }

    private func applyGradientBackground() {
        do {
            _ = try documentStore.updateSelectedDocument { document in
                document.background = .linearGradient(
                    colors: [backgroundHex, "#2563eb", "#38bdf8"],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        } catch {
            documentStore.setError(error.localizedDescription)
        }
    }

    private func applyRadialBackground() {
        do {
            _ = try documentStore.updateSelectedDocument { document in
                document.background = .radialGradient(
                    colors: ["#38bdf8", backgroundHex],
                    center: .center,
                    startRadius: 0,
                    endRadius: 720
                )
            }
        } catch {
            documentStore.setError(error.localizedDescription)
        }
    }

    private func addShape(_ shape: String) {
        do {
            let layer = defaultLayer(shape)
            _ = try documentStore.addLayer(layer)
            selectLayer(layer)
        } catch {
            documentStore.setError(error.localizedDescription)
        }
    }

    private func defaultLayer(_ shape: String) -> IconLayer {
        switch shape {
        case "rectangle":
            return IconLayer(name: L.string("Rectangle"), shape: .rectangle(x: 256, y: 256, width: 512, height: 512, cornerRadius: 96), fill: .color(selectedFillHex))
        case "circle":
            return IconLayer(name: L.string("Circle"), shape: .circle(cx: 512, cy: 512, radius: 260), fill: .color(selectedFillHex))
        case "capsule":
            return IconLayer(name: L.string("Capsule"), shape: .capsule(x: 224, y: 336, width: 576, height: 352), fill: .color(selectedFillHex))
        case "triangle":
            return IconLayer(name: L.string("Triangle"), shape: .triangle(x: 292, y: 232, width: 440, height: 560), fill: .color(selectedFillHex))
        case "line":
            return IconLayer(name: L.string("Line"), shape: .line(x1: 280, y1: 512, x2: 744, y2: 512), fill: .color(selectedFillHex), stroke: IconStroke(color: selectedFillHex, width: 32))
        case "symbol":
            return IconLayer(
                name: L.string("Symbol"),
                shape: .symbol(name: symbolName.isEmpty ? "sparkles" : symbolName, x: 512, y: 512, size: 420, weight: "semibold"),
                fill: .color(selectedFillHex),
                shadow: IconShadow(color: shadowColor, radius: 32, x: 0, y: 18)
            )
        case "text":
            return IconLayer(
                name: L.string("Text"),
                shape: .text(value: textValue.isEmpty ? "L" : textValue, x: 512, y: 512, size: 420, weight: "bold"),
                fill: .color(selectedFillHex),
                shadow: IconShadow(color: shadowColor, radius: 32, x: 0, y: 18)
            )
        default:
            return IconLayer(name: L.string("Rectangle"), shape: .rectangle(x: 256, y: 256, width: 512, height: 512, cornerRadius: 96), fill: .color(selectedFillHex))
        }
    }

    private func selectedLayer(document: IconDocument) -> IconLayer? {
        guard let selectedLayerId else { return nil }
        return document.layers.first { $0.id == selectedLayerId }
    }

    private func selectLayer(_ layer: IconLayer) {
        selectedLayerId = layer.id
        layerName = layer.name
        selectedFillHex = layer.fill.hexValue
        layerOpacity = layer.opacity
        translateX = layer.transform.translateX
        translateY = layer.transform.translateY
        layerScale = layer.transform.scale
        rotationDegrees = layer.transform.rotationDegrees
        shadowColor = layer.shadow?.color ?? "#00000040"
        shadowRadius = layer.shadow?.radius ?? 0
        shadowY = layer.shadow?.y ?? 12
        blurRadius = layer.blurRadius
        syncShapeInspector(layer: layer)
    }

    private func syncInspectorSelection(document: IconDocument) {
        backgroundHex = document.background.hexValue
        if let selectedLayerId, let layer = document.layers.first(where: { $0.id == selectedLayerId }) {
            selectLayer(layer)
        } else if let layer = document.layers.last {
            selectLayer(layer)
        } else {
            selectedLayerId = nil
        }
    }

    private func applySelectedLayerName() {
        guard let selectedLayerId else { return }
        do {
            _ = try documentStore.renameLayer(id: selectedLayerId, name: layerName)
        } catch {
            documentStore.setError(error.localizedDescription)
        }
    }

    private func applySelectedLayerStyle() {
        guard let selectedLayerId else { return }
        do {
            _ = try documentStore.updateLayer(id: selectedLayerId) { layer in
                layer.fill = .color(selectedFillHex)
                layer.opacity = layerOpacity
                if layer.stroke != nil {
                    layer.stroke?.color = selectedFillHex
                }
            }
        } catch {
            documentStore.setError(error.localizedDescription)
        }
    }

    private func syncShapeInspector(layer: IconLayer) {
        switch layer.shape {
        case .rectangle(let x, let y, let width, let height, let cornerRadius):
            shapeX = x
            shapeY = y
            shapeWidth = width
            shapeHeight = height
            shapeCornerRadius = cornerRadius
        case .capsule(let x, let y, let width, let height),
             .triangle(let x, let y, let width, let height):
            shapeX = x
            shapeY = y
            shapeWidth = width
            shapeHeight = height
        case .circle(let cx, let cy, let radius):
            circleCX = cx
            circleCY = cy
            circleRadius = radius
        case .line(let x1, let y1, let x2, let y2):
            lineX1 = x1
            lineY1 = y1
            lineX2 = x2
            lineY2 = y2
        case .symbol(let name, let x, let y, let size, let weight):
            symbolName = name
            shapeX = x
            shapeY = y
            shapeSize = size
            shapeWeight = weight
        case .text(let value, let x, let y, let size, let weight):
            textValue = value
            shapeX = x
            shapeY = y
            shapeSize = size
            shapeWeight = weight
        }
    }

    private func applySelectedLayerShape() {
        guard let selectedLayerId else { return }
        do {
            _ = try documentStore.updateLayer(id: selectedLayerId) { layer in
                switch layer.shape {
                case .rectangle:
                    layer.shape = .rectangle(
                        x: shapeX,
                        y: shapeY,
                        width: shapeWidth,
                        height: shapeHeight,
                        cornerRadius: shapeCornerRadius
                    )
                case .capsule:
                    layer.shape = .capsule(x: shapeX, y: shapeY, width: shapeWidth, height: shapeHeight)
                case .triangle:
                    layer.shape = .triangle(x: shapeX, y: shapeY, width: shapeWidth, height: shapeHeight)
                case .circle:
                    layer.shape = .circle(cx: circleCX, cy: circleCY, radius: circleRadius)
                case .line:
                    layer.shape = .line(x1: lineX1, y1: lineY1, x2: lineX2, y2: lineY2)
                case .symbol:
                    layer.shape = .symbol(
                        name: symbolName.isEmpty ? "app" : symbolName,
                        x: shapeX,
                        y: shapeY,
                        size: shapeSize,
                        weight: shapeWeight
                    )
                case .text:
                    layer.shape = .text(
                        value: textValue.isEmpty ? "A" : textValue,
                        x: shapeX,
                        y: shapeY,
                        size: shapeSize,
                        weight: shapeWeight
                    )
                }
            }
        } catch {
            documentStore.setError(error.localizedDescription)
        }
    }

    private func duplicateLayer(_ layer: IconLayer) {
        do {
            let result = try documentStore.duplicateLayer(id: layer.id)
            selectLayer(result.layer)
        } catch {
            documentStore.setError(error.localizedDescription)
        }
    }

    private func deleteLayer(_ layer: IconLayer) {
        do {
            let document = try documentStore.deleteLayer(id: layer.id)
            if selectedLayerId == layer.id {
                if let replacement = document.layers.last {
                    selectLayer(replacement)
                } else {
                    selectedLayerId = nil
                }
            }
        } catch {
            documentStore.setError(error.localizedDescription)
        }
    }

    private func moveLayer(_ layer: IconLayer, direction: LayerMoveDirection) {
        do {
            _ = try documentStore.moveLayer(id: layer.id, direction: direction)
            selectLayer(layer)
        } catch {
            documentStore.setError(error.localizedDescription)
        }
    }

    private func undoDocumentChange() {
        documentStore.undo()
        if let document = documentStore.selectedDocument {
            syncInspectorSelection(document: document)
        }
    }

    private func redoDocumentChange() {
        documentStore.redo()
        if let document = documentStore.selectedDocument {
            syncInspectorSelection(document: document)
        }
    }

    private func applySelectedLayerTransform() {
        guard let selectedLayerId else { return }
        do {
            _ = try documentStore.updateLayer(id: selectedLayerId) { layer in
                layer.transform.translateX = translateX
                layer.transform.translateY = translateY
                layer.transform.scale = layerScale
                layer.transform.rotationDegrees = rotationDegrees
            }
        } catch {
            documentStore.setError(error.localizedDescription)
        }
    }

    private func applySelectedLayerEffects() {
        guard let selectedLayerId else { return }
        do {
            _ = try documentStore.updateLayer(id: selectedLayerId) { layer in
                layer.shadow = shadowRadius > 0 ? IconShadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY) : nil
                layer.blurRadius = blurRadius
            }
        } catch {
            documentStore.setError(error.localizedDescription)
        }
    }

    private func refreshLintIssues() {
        guard let document = documentStore.selectedDocument else {
            lintIssues = []
            return
        }
        lintIssues = IconDocumentLinter().lint(document).issues
    }

    private func exportCurrentDesign() async {
        if let document = documentStore.selectedDocument {
            isExportingSVG = true
            defer { isExportingSVG = false }
            do {
                let outputURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("LumiAppIconDesigner", isDirectory: true)
                    .appendingPathComponent("\(document.title.fileSafeName)-\(document.id.prefix(8)).svg")
                try FileManager.default.createDirectory(
                    at: outputURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                let svg = IconSVGRenderer().render(document: document)
                try svg.write(to: outputURL, atomically: true, encoding: .utf8)
                documentStore.setExportURL(outputURL)
            } catch {
                documentStore.setError(error.localizedDescription)
            }
            return
        }

        await viewModel.exportSelected()
    }

    private func exportCurrentDocumentAppIconSet() async {
        guard let document = documentStore.selectedDocument else { return }
        isExportingSVG = true
        defer { isExportingSVG = false }

        do {
            let lintReport = IconDocumentLinter().lint(document)
            lintIssues = lintReport.issues
            let result = try AppIconExportService().exportAppIconSet(
                document: document,
                outputDirectory: viewModel.outputDirectoryURL()
            )
            lintIssues = result.lintWarnings
            documentStore.setExportURL(result.appIconSetURL)
        } catch {
            documentStore.setError(error.localizedDescription)
        }
    }

    private func saveCurrentDocument() {
        guard let document = documentStore.selectedDocument else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(document.title.fileSafeName).json"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try IconDocumentFileService().save(document: document, to: url)
            documentStore.setExportURL(url)
        } catch {
            documentStore.setError(error.localizedDescription)
        }
    }

    private func loadDocument() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let document = try IconDocumentFileService().load(from: url)
            let imported = documentStore.importDocument(document)
            selectedLayerId = imported.layers.last?.id
            syncInspectorSelection(document: imported)
            documentStore.setExportURL(url)
        } catch {
            documentStore.setError(error.localizedDescription)
        }
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

private extension String {
    var fileSafeName: String {
        let safe = lowercased()
            .replacingOccurrences(of: #"[^a-z0-9_-]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return safe.isEmpty ? "icon" : safe
    }
}

#Preview("App Icon Designer") {
    AppIconDesignerView()
        .frame(width: 900, height: 620)
}
