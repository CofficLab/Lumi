import AppKit
import SwiftUI

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
                Text("App Icon Designer")
                    .font(.headline)
                Text("Create vector icons with shape, color, layer, and export tools.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { await exportCurrentDesign() }
            } label: {
                Label("Export", systemImage: "square.and.arrow.down")
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
            TextField("Output directory", text: $viewModel.exportDirectory)
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
            .help("Export AppIcon.appiconset")
        }
        .padding(.horizontal, 24)
    }

    private var candidatesPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Candidates")
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
            Text("Inspector")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
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
            Text("Canvas")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 8) {
                TextField("Background", text: $backgroundHex)
                    .textFieldStyle(.roundedBorder)

                Button {
                    applyBackground()
                } label: {
                    Image(systemName: "paintbucket")
                }
                .help("Apply background color")
            }

            Text("\(Int(document.width)) x \(Int(document.height))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var addShapeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 8) {
                shapeButton("rectangle", icon: "rectangle")
                shapeButton("circle", icon: "circle")
                shapeButton("triangle", icon: "triangle")
                shapeButton("line", icon: "line.diagonal")
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
        .help("Add \(shape)")
    }

    private func layersSection(document: IconDocument) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Layers")
                .font(.subheadline.weight(.semibold))

            if document.layers.isEmpty {
                Text("No layers")
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
            Text("Layer")
                .font(.subheadline.weight(.semibold))

            if selectedLayer(document: document) == nil {
                Text("Select a layer to edit it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 8) {
                    TextField("Fill", text: $selectedFillHex)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        applySelectedLayerStyle()
                    } label: {
                        Image(systemName: "eyedropper")
                    }
                    .help("Apply fill color")
                }

                VStack(spacing: 8) {
                    Stepper(value: $translateX, in: -1024...1024, step: 8) {
                        Text("X \(Int(translateX))")
                            .font(.caption)
                    }
                    Stepper(value: $translateY, in: -1024...1024, step: 8) {
                        Text("Y \(Int(translateY))")
                            .font(.caption)
                    }
                    Stepper(value: $layerScale, in: 0.1...4, step: 0.1) {
                        Text("Scale \(String(format: "%.1f", layerScale))")
                            .font(.caption)
                    }
                    Stepper(value: $rotationDegrees, in: -360...360, step: 5) {
                        Text("Rotate \(Int(rotationDegrees))")
                            .font(.caption)
                    }
                }
                .onChange(of: translateX) { _, _ in applySelectedLayerTransform() }
                .onChange(of: translateY) { _, _ in applySelectedLayerTransform() }
                .onChange(of: layerScale) { _, _ in applySelectedLayerTransform() }
                .onChange(of: rotationDegrees) { _, _ in applySelectedLayerTransform() }
            }
        }
    }

    private var exportDocumentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Export")
                .font(.subheadline.weight(.semibold))

            Button {
                Task { await exportCurrentDesign() }
            } label: {
                if isExportingSVG {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Export SVG", systemImage: "square.and.arrow.down")
                }
            }
            .disabled(documentStore.selectedDocument == nil || isExportingSVG)
        }
    }

    private func documentPreviewPane(document: IconDocument) -> some View {
        VStack(spacing: 18) {
            Spacer(minLength: 16)

            IconDocumentPreviewView(document: document)
                .frame(width: 256, height: 256)
                .clipShape(RoundedRectangle(cornerRadius: 56, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 22, y: 12)

            VStack(spacing: 5) {
                Text(document.title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text("\(Int(document.width)) x \(Int(document.height)) vector document")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)

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

    private func iconName(for shape: IconShape) -> String {
        switch shape {
        case .rectangle:
            return "rectangle"
        case .circle:
            return "circle"
        case .triangle:
            return "triangle"
        case .line:
            return "line.diagonal"
        }
    }

    private func layerRow(_ layer: IconLayer) -> some View {
        Button {
            selectLayer(layer)
        } label: {
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
            }
            .padding(8)
            .background(rowBackground(isSelected: selectedLayerId == layer.id))
        }
        .buttonStyle(.plain)
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
        VStack(spacing: 14) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 46))
                .foregroundStyle(.secondary)

            Text("No icon candidate yet")
                .font(.title3.weight(.semibold))

            Text("Create a blank vector canvas and start building an icon with shapes, colors, and layers.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)

            Button {
                createBlankDocument()
            } label: {
                Label("New Icon", systemImage: "plus")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private func createBlankDocument() {
        let document = documentStore.createDocument(
            title: "Untitled Icon",
            width: 1024,
            height: 1024,
            background: .color(backgroundHex)
        )
        selectedLayerId = document.layers.first?.id
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
            return IconLayer(name: "Rectangle", shape: .rectangle(x: 256, y: 256, width: 512, height: 512, cornerRadius: 96), fill: .color(selectedFillHex))
        case "circle":
            return IconLayer(name: "Circle", shape: .circle(cx: 512, cy: 512, radius: 260), fill: .color(selectedFillHex))
        case "triangle":
            return IconLayer(name: "Triangle", shape: .triangle(x: 292, y: 232, width: 440, height: 560), fill: .color(selectedFillHex))
        case "line":
            return IconLayer(name: "Line", shape: .line(x1: 280, y1: 512, x2: 744, y2: 512), fill: .color(selectedFillHex), stroke: IconStroke(color: selectedFillHex, width: 32))
        default:
            return IconLayer(name: "Rectangle", shape: .rectangle(x: 256, y: 256, width: 512, height: 512, cornerRadius: 96), fill: .color(selectedFillHex))
        }
    }

    private func selectedLayer(document: IconDocument) -> IconLayer? {
        guard let selectedLayerId else { return nil }
        return document.layers.first { $0.id == selectedLayerId }
    }

    private func selectLayer(_ layer: IconLayer) {
        selectedLayerId = layer.id
        selectedFillHex = layer.fill.hexValue
        translateX = layer.transform.translateX
        translateY = layer.transform.translateY
        layerScale = layer.transform.scale
        rotationDegrees = layer.transform.rotationDegrees
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

    private func applySelectedLayerStyle() {
        guard let selectedLayerId else { return }
        do {
            _ = try documentStore.updateLayer(id: selectedLayerId) { layer in
                layer.fill = .color(selectedFillHex)
                if layer.stroke != nil {
                    layer.stroke?.color = selectedFillHex
                }
            }
        } catch {
            documentStore.setError(error.localizedDescription)
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

private struct IconDocumentPreviewView: View {
    let document: IconDocument

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / document.width, proxy.size.height / document.height)
            let xOffset = (proxy.size.width - document.width * scale) / 2
            let yOffset = (proxy.size.height - document.height * scale) / 2

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(color(for: document.background))
                    .frame(width: document.width * scale, height: document.height * scale)
                    .position(x: xOffset + document.width * scale / 2, y: yOffset + document.height * scale / 2)

                ForEach(document.layers) { layer in
                    layerView(layer: layer, scale: scale)
                        .opacity(layer.opacity)
                        .scaleEffect(layer.transform.scale)
                        .rotationEffect(.degrees(layer.transform.rotationDegrees))
                        .offset(
                            x: xOffset + layer.transform.translateX * scale,
                            y: yOffset + layer.transform.translateY * scale
                        )
                }
            }
        }
    }

    @ViewBuilder
    private func layerView(layer: IconLayer, scale: Double) -> some View {
        switch layer.shape {
        case .rectangle(let x, let y, let width, let height, let cornerRadius):
            RoundedRectangle(cornerRadius: cornerRadius * scale, style: .continuous)
                .fill(color(for: layer.fill))
                .frame(width: width * scale, height: height * scale)
                .position(x: (x + width / 2) * scale, y: (y + height / 2) * scale)
        case .circle(let cx, let cy, let radius):
            Circle()
                .fill(color(for: layer.fill))
                .frame(width: radius * 2 * scale, height: radius * 2 * scale)
                .position(x: cx * scale, y: cy * scale)
        case .triangle(let x, let y, let width, let height):
            TriangleShape()
                .fill(color(for: layer.fill))
                .frame(width: width * scale, height: height * scale)
                .position(x: (x + width / 2) * scale, y: (y + height / 2) * scale)
        case .line(let x1, let y1, let x2, let y2):
            Path { path in
                path.move(to: CGPoint(x: x1 * scale, y: y1 * scale))
                path.addLine(to: CGPoint(x: x2 * scale, y: y2 * scale))
            }
            .stroke(color(for: layer.fill), style: StrokeStyle(lineWidth: max(1, (layer.stroke?.width ?? 8) * scale), lineCap: .round))
        }
    }

    private func color(for paint: IconPaint) -> Color {
        switch paint {
        case .color(let value):
            return Color(iconHex: value)
        }
    }
}

private struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private extension Color {
    init(iconHex: String) {
        let trimmed = iconHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&value)

        switch trimmed.count {
        case 8:
            self.init(
                .sRGB,
                red: Double((value >> 24) & 0xff) / 255,
                green: Double((value >> 16) & 0xff) / 255,
                blue: Double((value >> 8) & 0xff) / 255,
                opacity: Double(value & 0xff) / 255
            )
        case 6:
            self.init(
                .sRGB,
                red: Double((value >> 16) & 0xff) / 255,
                green: Double((value >> 8) & 0xff) / 255,
                blue: Double(value & 0xff) / 255,
                opacity: 1
            )
        default:
            self = .clear
        }
    }
}

private extension IconPaint {
    var hexValue: String {
        switch self {
        case .color(let value):
            return value
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
