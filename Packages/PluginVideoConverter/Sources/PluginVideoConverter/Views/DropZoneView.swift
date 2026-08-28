import SwiftUI
import UniformTypeIdentifiers

/// Drop zone view for selecting video files.
struct DropZoneView: View {
    @ObservedObject var viewModel: VideoConverterViewModel
    @State private var isTargeted = false

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
                if let file = viewModel.selectedFile {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text(file.lastPathComponent)
                        .font(.headline)
                        .lineLimit(1)
                    Text(ByteCountFormatter.string(fromByteCount: Int64(file.fileSize), countStyle: .file))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(VideoConverterLocalization.string("Clear")) {
                        viewModel.clearSelection()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text(VideoConverterLocalization.string("Drag & drop a video file here"))
                        .font(.headline)
                    Text(VideoConverterLocalization.string("or click to browse"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .frame(height: viewModel.selectedFile == nil ? 160 : 180)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            viewModel.handleDrop(providers: providers)
        }
        .onTapGesture {
            viewModel.pickFile()
        }
    }
}

#Preview {
    DropZoneView(viewModel: VideoConverterViewModel())
        .padding()
        .frame(width: 400, height: 200)
}
