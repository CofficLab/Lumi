import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// View model for the Video Converter plugin.
@MainActor
final class VideoConverterViewModel: ObservableObject {
    @Published var selectedFile: VideoFileItem?
    @Published var outputFormat: VideoFormat = .mp4
    @Published var isConverting = false
    @Published var progress: Double = 0
    @Published var conversionLog: String = ""

    private var conversionTask: Process?
    private let converter = VideoConverterService()

    // MARK: - File Selection

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
            // Extract URL synchronously before crossing actor boundary
            guard let data = data as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            Task { @MainActor in
                await self.loadFile(url: url)
            }
        }
        return true
    }

    func pickFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie, .avi, .webArchive]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            Task { await loadFile(url: url) }
        }
    }

    private func loadFile(url: URL) async {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = (attrs?[.size] as? UInt64) ?? 0
        selectedFile = VideoFileItem(url: url, fileSize: fileSize)
        conversionLog = ""
        progress = 0
    }

    func clearSelection() {
        selectedFile = nil
        conversionLog = ""
        progress = 0
    }

    // MARK: - Conversion

    func startConversion() {
        guard let file = selectedFile else { return }
        guard !isConverting else { return }

        isConverting = true
        progress = 0
        conversionLog = VideoConverterLocalization.string(
            "Converting %@ → %@...",
            file.lastPathComponent,
            outputFormat.displayName
        ) + "\n"

        Task {
            do {
                let outputPath = file.url.deletingPathExtension()
                    .appendingPathExtension(outputFormat.rawValue)
                    .path

                try await converter.convert(
                    input: file.url,
                    output: URL(fileURLWithPath: outputPath),
                    format: outputFormat,
                    onProgress: { [weak self] percent in
                        Task { @MainActor in
                            self?.progress = percent
                        }
                    },
                    onLog: { [weak self] line in
                        Task { @MainActor in
                            self?.conversionLog += line + "\n"
                        }
                    }
                )

                conversionLog += "✅ \(VideoConverterLocalization.string("Conversion completed!"))\n"
                progress = 1.0
            } catch {
                conversionLog += "❌ \(VideoConverterLocalization.string("Error: %@", error.localizedDescription))\n"
            }

            isConverting = false
        }
    }

    func cancelConversion() {
        Task {
            await converter.cancel()
            isConverting = false
            conversionLog += "⚠️ \(VideoConverterLocalization.string("Conversion cancelled."))\n"
        }
    }
}
