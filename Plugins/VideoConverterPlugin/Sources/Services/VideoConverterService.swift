import Foundation
import SuperLogKit
import os

/// Service that wraps FFmpeg CLI for video conversion.
actor VideoConverterService: SuperLog {
    nonisolated static let emoji = "🎬"
    nonisolated static let verbose: Bool = true
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.video-converter")
    private var currentProcess: Process?

    /// Convert a video file to the specified format using FFmpeg.
    func convert(
        input: URL,
        output: URL,
        format: VideoFormat,
        onProgress: @escaping @Sendable (Double) -> Void,
        onLog: @escaping @Sendable (String) -> Void
    ) async throws {
        let ffmpegPath = try await resolveFFmpegPath()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)

        var args: [String] = [
            "-i", input.path,
            "-c:v", format.ffmpegCodec,
            "-y", // overwrite
        ]

        if let ffmpegFormat = format.ffmpegFormat {
            args.append(contentsOf: ["-f", ffmpegFormat])
        }

        args.append(output.path)

        process.arguments = args
        process.standardOutput = FileHandle.nullDevice

        let pipe = Pipe()
        process.standardError = pipe

        // Parse progress from FFmpeg stderr
        var totalDuration: Double = 0

        // First, probe duration
        totalDuration = await probeDuration(ffmpegPath: ffmpegPath, inputPath: input.path)

        let handle = pipe.fileHandleForReading
        let outputStream = AsyncStream<Data> { continuation in
            handle.readabilityHandler = { fileHandle in
                let data = fileHandle.availableData
                if data.isEmpty {
                    continuation.finish()
                } else {
                    continuation.yield(data)
                }
            }
        }

        currentProcess = process
        onLog("FFmpeg: \(ffmpegPath)")
        onLog("Args: \(args.joined(separator: " "))")

        try process.run()

        // Parse progress from stderr
        Task {
            for await data in outputStream {
                if let line = String(data: data, encoding: .utf8) {
                    if totalDuration > 0, let time = parseTime(line), time > 0 {
                        let percent = min(time / totalDuration, 1.0)
                        onProgress(percent)
                    }
                }
            }
        }

        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw VideoConverterError.conversionFailed(exitCode: process.terminationStatus)
        }

        onProgress(1.0)
    }

    /// Cancel the running FFmpeg process.
    func cancel() {
        currentProcess?.terminate()
        currentProcess = nil
    }

    // MARK: - Private

    private func resolveFFmpegPath() async throws -> String {
        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg",
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Try which ffmpeg
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ffmpeg"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
            return path
        }

        throw VideoConverterError.ffmpegNotFound
    }

    private func probeDuration(ffmpegPath: String, inputPath: String) async -> Double {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = ["-i", inputPath, "-f", "null", "-"]

        let pipe = Pipe()
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return parseDuration(output) ?? 0
            }
        } catch {
            Self.logger.error("\(Self.t)Probe video duration failed: \(error.localizedDescription)")
        }

        return 0
    }

    /// Parse "Duration: HH:MM:SS.xx" from FFmpeg output.
    private func parseDuration(_ text: String) -> Double? {
        let pattern = #"Duration:\s*(\d{2}):(\d{2}):(\d{2})\.(\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }

        let hours = Double(text[Range(match.range(at: 1), in: text)!]) ?? 0
        let minutes = Double(text[Range(match.range(at: 2), in: text)!]) ?? 0
        let seconds = Double(text[Range(match.range(at: 3), in: text)!]) ?? 0
        let centiseconds = Double(text[Range(match.range(at: 4), in: text)!]) ?? 0

        return hours * 3600 + minutes * 60 + seconds + centiseconds / 100
    }

    /// Parse "time=HH:MM:SS.xx" from FFmpeg progress output.
    private func parseTime(_ text: String) -> Double? {
        let pattern = #"time=(\d{2}):(\d{2}):(\d{2})\.(\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }

        let hours = Double(text[Range(match.range(at: 1), in: text)!]) ?? 0
        let minutes = Double(text[Range(match.range(at: 2), in: text)!]) ?? 0
        let seconds = Double(text[Range(match.range(at: 3), in: text)!]) ?? 0
        let centiseconds = Double(text[Range(match.range(at: 4), in: text)!]) ?? 0

        return hours * 3600 + minutes * 60 + seconds + centiseconds / 100
    }
}

// MARK: - Errors

enum VideoConverterError: LocalizedError {
    case ffmpegNotFound
    case conversionFailed(exitCode: Int32)

    var errorDescription: String? {
        switch self {
        case .ffmpegNotFound:
            return VideoConverterLocalization.string("FFmpeg not found. Please install it via `brew install ffmpeg`.")
        case .conversionFailed(let code):
            return VideoConverterLocalization.string("FFmpeg exited with error code %lld.", code)
        }
    }
}
