import Foundation
import Testing

@testable import PluginVideoConverter

/// #209 回归：时长探测与转换的进程管理。
///
/// 用可执行 shell 脚本替身模拟 ffmpeg：按参数区分「探测」与「转换」，
/// 转换分支可以输出远超管道缓冲（64KB）的 stderr，复现「先 wait 后读」
/// 的永久死锁；脚本内置自杀闹钟，变异验证时也不会挂死测试进程。
@Suite("VideoConverterService 进程管理")
struct VideoConverterServiceProcessTests {
    // MARK: - 脚本替身

    /// 探测分支打印 Duration 后立即退出；转换分支输出 ~380KB stderr 后退出。
    private static let floodScript = """
    #!/bin/sh
    case "$*" in
      *-c:v*)
        (sleep 12; kill $$ 2>/dev/null) 2>/dev/null &
        i=0
        while [ $i -lt 4000 ]; do
          printf 'frame=  100 fps= 30 q=28.0 size=    1024kB time=00:00:01.00 bitrate= 100.0kbits/s speed=1.00x\\n' >&2
          i=$((i+1))
        done
        exit 0
        ;;
      *)
        printf 'Duration: 00:01:00.00, start: 0.000000, bitrate: 100 kb/s\\n' >&2
        exit 0
        ;;
    esac
    """

    /// 转换分支长时间 sleep；cancel 必须能立刻终止它。
    private static let slowConversionScript = """
    #!/bin/sh
    case "$*" in
      *-c:v*)
        (sleep 12; kill $$ 2>/dev/null) 2>/dev/null &
        printf 'frame= 1 time=00:00:00.10\\n' >&2
        sleep 30
        exit 0
        ;;
      *)
        printf 'Duration: 00:01:00.00\\n' >&2
        exit 0
        ;;
    esac
    """

    /// 探测分支长时间 sleep；转换分支写标记文件（不该被跑到）。
    private static func slowProbeScript(markerPath: String) -> String {
        """
        #!/bin/sh
        case "$*" in
          *-c:v*)
            echo ran > '\(markerPath)'
            exit 0
            ;;
          *)
            (sleep 12; kill $$ 2>/dev/null) 2>/dev/null &
            sleep 30
            exit 0
            ;;
        esac
        """
    }

    /// 探测分支按是否带 `-f null`（全量解码）返回不同 Duration；
    /// 转换分支输出一条 time= 进度。元数据探测应拿到 150.5s。
    private static let metadataScript = """
    #!/bin/sh
    case "$*" in
      *-c:v*)
        printf 'frame= 100 time=00:01:15.25\\n' >&2
        exit 0
        ;;
      *null*)
        printf 'Duration: 00:00:00.00\\n' >&2
        exit 0
        ;;
      *)
        printf 'Duration: 00:02:30.50\\n' >&2
        exit 0
        ;;
    esac
    """

    private static let failingScript = """
    #!/bin/sh
    case "$*" in
      *-c:v*)
        exit 3
        ;;
      *)
        printf 'Duration: 00:01:00.00\\n' >&2
        exit 0
        ;;
    esac
    """

    // MARK: - 基建

    private struct Harness {
        let directory: URL
        let script: URL
        let input: URL
        let output: URL
    }

    private func makeHarness(script: String) throws -> Harness {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("video-converter-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let scriptURL = directory.appendingPathComponent("fake-ffmpeg")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        let input = directory.appendingPathComponent("input.mp4")
        try Data("not-a-real-video".utf8).write(to: input)
        return Harness(
            directory: directory,
            script: scriptURL,
            input: input,
            output: directory.appendingPathComponent("output.mp4")
        )
    }

    private func makeService(script: URL) async -> VideoConverterService {
        let service = VideoConverterService()
        await service.setFFmpegPathOverride(script.path)
        return service
    }

    /// 轮询等待条件成立，超时抛错（避免测试挂死）。
    private func waitUntil(
        timeoutSeconds: Double = 10,
        _ condition: @Sendable () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while !condition() {
            if Date() > deadline {
                throw ServiceTestError.waitTimeout
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private enum ServiceTestError: Error {
        case waitTimeout
    }

    // MARK: - 用例

    @Test("转换输出超过管道缓冲的 stderr 仍能完成（死锁回归）")
    func conversionWithLargeStderrCompletes() async throws {
        let harness = try makeHarness(script: Self.floodScript)
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let service = await makeService(script: harness.script)
        let progress = PercentBox()

        // 旧实现先 waitUntilExit 后读管道：脚本写满 64KB 管道即互相等待。
        // 脚本的 12s 自杀闹钟保证变异验证时以失败告终而不是挂死。
        try await service.convert(
            input: harness.input,
            output: harness.output,
            format: .mp4,
            onProgress: { progress.record($0) },
            onLog: { _ in }
        )
        #expect(progress.max == 1.0)
    }

    @Test("转换进行中 cancel 能立刻终止进程")
    func cancelDuringConversionStopsPromptly() async throws {
        let harness = try makeHarness(script: Self.slowConversionScript)
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let service = await makeService(script: harness.script)
        let log = LogBox()

        let task = Task {
            try await service.convert(
                input: harness.input,
                output: harness.output,
                format: .mp4,
                onProgress: { _ in },
                onLog: { log.append($0) }
            )
        }
        // 等到转换进程真正启动（Args 日志在 run 之前发出）。
        try await waitUntil { log.contains("Args:") }
        let start = Date()
        await service.cancel()

        do {
            try await task.value
            Issue.record("取消后 convert 不应正常返回")
        } catch is CancellationError {
            // 预期路径
        } catch {
            Issue.record("取消后应抛 CancellationError，实际：\(error)")
        }
        // 旧实现 waitUntilExit 阻塞 actor，cancel 排不进来，只能等 12s 自杀。
        #expect(Date().timeIntervalSince(start) < 5)
    }

    @Test("探测进行中 cancel 能终止探测且不进入转换")
    func cancelDuringProbeStopsPromptly() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("video-converter-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let marker = directory.appendingPathComponent("conversion-ran")
        let scriptURL = directory.appendingPathComponent("fake-ffmpeg")
        try Self.slowProbeScript(markerPath: marker.path)
            .write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        let input = directory.appendingPathComponent("input.mp4")
        try Data("not-a-real-video".utf8).write(to: input)

        let service = VideoConverterService()
        await service.setFFmpegPathOverride(scriptURL.path)

        let task = Task {
            try await service.convert(
                input: input,
                output: directory.appendingPathComponent("output.mp4"),
                format: .mp4,
                onProgress: { _ in },
                onLog: { _ in }
            )
        }
        // 探测在 convert 一开始就启动；留出进入探测的时间。
        try await Task.sleep(nanoseconds: 300_000_000)
        let start = Date()
        await service.cancel()

        do {
            try await task.value
            Issue.record("取消后 convert 不应正常返回")
        } catch is CancellationError {
            // 预期路径
        } catch {
            Issue.record("取消后应抛 CancellationError，实际：\(error)")
        }
        #expect(Date().timeIntervalSince(start) < 5)
        #expect(!FileManager.default.fileExists(atPath: marker.path))
    }

    @Test("时长按元数据探测，不做全量解码")
    func probeReadsMetadataWithoutFullDecode() async throws {
        let harness = try makeHarness(script: Self.metadataScript)
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let service = await makeService(script: harness.script)
        let progress = PercentBox()

        try await service.convert(
            input: harness.input,
            output: harness.output,
            format: .mp4,
            onProgress: { progress.record($0) },
            onLog: { _ in }
        )
        // 元数据分支 Duration=150.5s，time=75.25s → 50%（结束还会报 1.0）。
        // 旧实现带 `-f null` 走全量解码分支拿到 0，进度恒为 0。
        #expect(progress.recorded.contains { abs($0 - 0.5) < 0.001 })
        #expect(progress.max == 1.0)
    }

    @Test("转换进程非零退出仍抛出 conversionFailed")
    func failedConversionThrows() async throws {
        let harness = try makeHarness(script: Self.failingScript)
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let service = await makeService(script: harness.script)

        do {
            try await service.convert(
                input: harness.input,
                output: harness.output,
                format: .mp4,
                onProgress: { _ in },
                onLog: { _ in }
            )
            Issue.record("非零退出应抛出 conversionFailed")
        } catch VideoConverterError.conversionFailed(let code) {
            #expect(code == 3)
        }
    }
}

// MARK: - 线程安全收集盒

private final class PercentBox: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Double] = []

    var max: Double {
        lock.lock()
        defer { lock.unlock() }
        return values.max() ?? 0
    }

    var recorded: [Double] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }

    func record(_ percent: Double) {
        lock.lock()
        values.append(percent)
        lock.unlock()
    }
}

private final class LogBox: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [String] = []

    func append(_ line: String) {
        lock.lock()
        lines.append(line)
        lock.unlock()
    }

    func contains(_ fragment: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return lines.contains { $0.contains(fragment) }
    }
}