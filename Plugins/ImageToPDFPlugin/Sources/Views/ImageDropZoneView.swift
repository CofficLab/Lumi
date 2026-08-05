import SwiftUI
import UniformTypeIdentifiers

/// Drag-and-drop zone for image files.
struct ImageDropZoneView: View {
    @ObservedObject var viewModel: ImageToPDFViewModel
    @State private var isTargeted: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8])
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isTargeted ? Color.accentColor.opacity(0.05) : Color.clear)
                )

            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)

                Text(ImageToPDFLocalization.string("Drag & drop image files here"))
                    .font(.headline)

                Text(ImageToPDFLocalization.string("or click to browse"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(
                    String(
                        format: ImageToPDFLocalization.string("Files: %lld"),
                        viewModel.inputImages.count
                    )
                )
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            .padding()
        }
        .frame(minHeight: 160)
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
        .onTapGesture {
            viewModel.pickImages()
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        var urls: [URL] = []

        for provider in providers {
            guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else {
                continue
            }
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                defer { group.leave() }
                if let data = data as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                }
            }
        }

        group.notify(queue: .main) {
            viewModel.addImages(from: urls)
        }
        return true
    }
}

#Preview {
    ImageDropZoneView(viewModel: ImageToPDFViewModel())
        .padding()
        .frame(width: 420)
}