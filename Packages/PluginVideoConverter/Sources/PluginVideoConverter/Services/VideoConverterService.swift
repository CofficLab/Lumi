import Foundation
import LumiLoggingKit
import os

/// Service that wraps FFmpeg CLI for video conversion.
actor VideoConverterService: SuperLog {
    nonisolated static let emoji = "🎬"
    nonisolated static let verbose: Bool = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.video-converter")
    private var currentProcess: Process?
    private var isCancelled = false

    /// 测试接缝：直接指定 ffmpeg 可执行文件，跳过真实路径探测。
    private var ffmpegPathOverride: String?

    func setFFmpegPathOverride(_ path: String?) {
        ffmpegPathOverride = path
    }

    /// Convert a video file to the specified format using FFmpeg.
    func convert(
        input: URL,
        output: URL,
        format: VideoFormat,
        onProgress: @escaping @Sendable (Double) -> Void,
        onLog: @escaping @Sendable (String) -> Void
    ) async throws {
        isCancelled = false
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
        let handle = pipe.fileHandleForReading
        // 确定性回收管道 fd，避免依赖 autorelease pool 造成 fd 泄漏。
        defer {
            handle.readabilityHandler = nil
            try? pipe.fileHandleForReading.close()
            try? pipe.fileHandleForWriting.close()
            currentProcess = nil
        }
        process.standardError = pipe

        // First, probe duration（只读元数据；探测进程同样可被 cancel 终止）
        let totalDuration = await probeDuration(ffmpegPath: ffmpegPath, inputPath: input.path)
        try checkCancellation()

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

        // stderr 必须与进程退出并发排空：先 wait 后读会在管道写满时
        // 与 FFmpeg 互相等待，永久死锁（#209）。
        let parseTask = Task {
            for await data in outputStream {
                if let line = String(data: data, encoding: .utf8) {
                    if totalDuration > 0, let time = parseTime(line), time > 0 {
                        let percent = min(time / totalDuration, 1.0)
                        onProgress(percent)
                    }
                }
            }
        }

        do {
            try await runAndWaitForExit(process)
        } catch {
            parseTask.cancel()
            throw error
        }
        await parseTask.value

        try checkCancellation()
        if process.terminationStatus != 0 {
            throw VideoConverterError.conversionFailed(exitCode: process.terminationStatus)
        }

        onProgress(1.0)
    }

    /// Cancel the running FFmpeg process (probe or conversion).
    func cancel() {
        isCancelled = true
        if let process = currentProcess, process.isRunning {
            process.terminate()
        }
        currentProcess = nil
    }

    // MARK: - Private

    private func checkCancellation() throws {
        if isCancelled {
            throw CancellationError()
        }
    }

    /// 启动进程并异步等待退出。
    ///
    /// 绝不在 actor 内同步 `waitUntilExit`：那会阻塞 actor，
    /// 让 `cancel()` 永远排不进来（#209）。terminationHandler 必须在
    /// run 之前设置，避免「进程已退出才装 handler」的竞态。
    private func runAndWaitForExit(_ process: Process) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { _ in
                continuation.resume()
            }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }

    private func resolveFFmpegPath() async throws -> String {
        if let ffmpegPathOverride {
            return ffmpegPathOverride
        }

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
        // 确定性回收管道 fd，避免依赖 autorelease pool 造成 fd 泄漏。
        defer {
            try? pipe.fileHandleForReading.close()
            try? pipe.fileHandleForWriting.close()
        }
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
        // 只读容器元数据：`-i` 不带输出参数时 ffmpeg 打印 Duration 后立即退出。
        // 旧实现 `-f null -` 会完整解码整个视频，长视频探测极慢且 stderr 巨大（#209）。
        process.arguments = ["-hide_banner", "-i", inputPath]
        process.standardOutput = FileHandle.nullDevice

        let pipe = Pipe()
        let handle = pipe.fileHandleForReading
        // 确定性回收管道 fd，避免依赖 autorelease pool 造成 fd 泄漏。
        defer {
            handle.readabilityHandler = nil
            try? pipe.fileHandleForReading.close()
            try? pipe.fileHandleForWriting.close()
            currentProcess = nil
        }
        process.standardError = pipe

        let stream = AsyncStream<Data> { continuation in
            handle.readabilityHandler = { fileHandle in
                let data = fileHandle.availableData
                if data.isEmpty {
                    continuation.finish()
                } else {
                    continuation.yield(data)
                }
            }
        }

        let collect = Task {
            var output = Data()
            for await chunk in stream {
                output.append(chunk)
            }
            return output
        }

        do {
            // 探测进程也交给 cancel 管理；否则取消只能等转换阶段才生效。
            currentProcess = process
            try await runAndWaitForExit(process)
            let data = await collect.value
            if let output = String(data: data, encoding: .utf8) {
                return parseDuration(output) ?? 0
            }
        } catch {
            collect.cancel()
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
