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
    private let converter: any VideoConverting
    /// 转换回合代号：每次开始转换递增，切换/清空选择也递增。回调与收尾写回前
    /// 比对代号，旧回合的迟到进度/日志/完成态一律拒绝，不得污染新选择（#263）。
    private var conversionGeneration = 0

    init(converter: any VideoConverting = VideoConverterService()) {
        self.converter = converter
    }

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

    func loadFile(url: URL) async {
        invalidateActiveConversion()
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = (attrs?[.size] as? UInt64) ?? 0
        selectedFile = VideoFileItem(url: url, fileSize: fileSize)
        conversionLog = ""
        progress = 0
    }

    func clearSelection() {
        invalidateActiveConversion()
        selectedFile = nil
        conversionLog = ""
        progress = 0
    }

    /// 切换/清空选择时作废旧回合：递增代号拒绝其迟到回调，并取消底层进程，
    /// 避免旧任务在后台继续跑、把进度/日志/完成态写进新选择（#263）。
    private func invalidateActiveConversion() {
        conversionGeneration += 1
        guard isConverting else { return }
        isConverting = false
        let converter = self.converter
        Task { await converter.cancel() }
    }

    // MARK: - Conversion

    func startConversion() {
        guard let file = selectedFile else { return }
        guard !isConverting else { return }

        isConverting = true
        progress = 0
        conversionGeneration += 1
        let generation = conversionGeneration
        conversionLog = VideoConverterLocalization.string(
            "Converting %@ → %@...",
            file.lastPathComponent,
            outputFormat.displayName
        ) + "\n"

        Task {
            do {
                let outputURL = Self.makeOutputURL(for: file.url, format: outputFormat)

                try await converter.convert(
                    input: file.url,
                    output: outputURL,
                    format: outputFormat,
                    onProgress: { [weak self] percent in
                        Task { @MainActor in
                            guard let self, self.conversionGeneration == generation else { return }
                            self.progress = percent
                        }
                    },
                    onLog: { [weak self] line in
                        Task { @MainActor in
                            guard let self, self.conversionGeneration == generation else { return }
                            self.conversionLog += line + "\n"
                        }
                    }
                )

                guard generation == conversionGeneration else { return }
                conversionLog += "✅ \(VideoConverterLocalization.string("Conversion completed!"))\n"
                progress = 1.0
            } catch is CancellationError {
                // 用户取消：cancelConversion 已记录取消日志，不再叠加错误行。
            } catch {
                guard generation == conversionGeneration else { return }
                conversionLog += "❌ \(VideoConverterLocalization.string("Error: %@", error.localizedDescription))\n"
            }

            // 旧回合被作废后不得复位新回合的 isConverting（#263）。
            guard generation == conversionGeneration else { return }
            isConverting = false
        }
    }

    // MARK: - Output Path

    /// Builds the conversion output URL, guaranteeing it never points at the
    /// input file. A same-format conversion (e.g. MP4 → MP4) would otherwise
    /// reproduce the input path, and FFmpeg refuses to read and write the same
    /// file, so the default operation path could not complete (#378).
    ///
    /// 比较忽略大小写：macOS 默认卷大小写不敏感，`movie.MP4` 与 `movie.mp4`
    /// 指向同一文件；即便在大小写敏感卷上误判，也只是多加一个后缀，绝不会写回输入。
    nonisolated static func makeOutputURL(for input: URL, format: VideoFormat) -> URL {
        let base = input.deletingPathExtension().appendingPathExtension(format.rawValue)
        if base.path.caseInsensitiveCompare(input.path) != .orderedSame {
            return base
        }
        let stem = input.deletingPathExtension().lastPathComponent
        return input.deletingLastPathComponent()
            .appendingPathComponent(stem + "-converted")
            .appendingPathExtension(format.rawValue)
    }

    func cancelConversion() {
        Task {
            await converter.cancel()
            isConverting = false
            conversionLog += "⚠️ \(VideoConverterLocalization.string("Conversion cancelled."))\n"
        }
    }
}
