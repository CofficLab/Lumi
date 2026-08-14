import Foundation
import KernelLumi

/// `start_recording`：开始录制某个 app 的窗口或整个屏幕，输出到下载目录。
///
/// `riskLevel` 为 `.high`，触发原生确认门；`willSendToLLM` 引导 LLM 在调用前先与用户
/// 对齐目标 app / 时长 / 声音 / 文件名 / 目录等细节。
public struct StartRecordingTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "start_recording",
        displayName: "Start Recording",
        description: """
        Start recording an app's window (or the whole screen) to a video file. \
        Ask the user to confirm the target app, whether to include audio, the output filename, \
        and the output directory (default ~/Downloads) before calling this tool. \
        The user can stop recording by saying "stop" or clicking the floating Stop button.
        """
    )

    public init() {}

    public var tags: Set<LumiToolTag> { [.sideEffect] }

    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel { .high }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        let app = arguments.string("application") ?? "screen"
        return "Recording \(app)"
    }

    public var inputSchema: LumiJSONValue {
        let str = { (desc: String) in LumiJSONValue.object(["type": .string("string"), "description": .string(desc)]) }
        return .object([
            "type": .string("object"),
            "properties": .object([
                "application": str("Target app name or bundle id (e.g. 'Maps' / 'com.apple.Maps'). Required when target is 'app_window'."),
                "window_title": str("Optional window-title substring to disambiguate multiple windows."),
                "target": .object([
                    "type": .string("string"),
                    "enum": .array([.string("app_window"), .string("display")]),
                    "default": .string("app_window"),
                    "description": .string("'app_window' (default) records a single app window; 'display' records the whole screen."),
                ]),
                "duration_seconds": .object([
                    "type": .string("integer"),
                    "minimum": .int(1),
                    "maximum": .int(3600),
                    "description": .string("Optional auto-stop duration in seconds."),
                ]),
                "include_app_audio": .object(["type": .string("boolean"), "default": .bool(false)]),
                "include_microphone": .object(["type": .string("boolean"), "default": .bool(false)]),
                "frame_rate": .object(["type": .string("integer"), "default": .int(30)]),
                "resolution_height": .object(["type": .string("integer"), "description": .string("Optional output height, e.g. 720 or 1080.")]),
                "output_directory": str("Output directory; default ~/Downloads."),
                "filename": str("Output filename (no extension); default recording-<timestamp>."),
            ]),
            "required": .array([.string("application")]),
            "additionalProperties": .bool(false),
        ])
    }

    @MainActor
    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        try kernel.checkCancellation()

        let targetKind = arguments.string("target") ?? "app_window"
        let application = arguments.string("application") ?? ""
        let windowTitle = arguments.string("window_title")

        // 目标解析。
        let target: RecordingTarget
        if targetKind == "display" {
            target = .display(excludeLumi: true)
        } else {
            guard !application.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RecordingError.noSuchWindow(application)
            }
            target = .appWindow(application: application, windowTitle: windowTitle)
        }

        // 输出目录解析与沙盒校验（在 execute 上下文内存活，时机正确）。
        let outputDir: URL
        do {
            outputDir = try RecordingToolSupport.resolveOutputDirectory(arguments.string("output_directory"), kernel: kernel)
        } catch let error as RecordingError {
            return RecordingToolSupport.describe(error, kernel: kernel)
        }

        let config = RecordingConfig(
            target: target,
            frameRate: arguments.int("frame_rate") ?? 30,
            resolutionHeight: arguments.int("resolution_height"),
            includeAppAudio: arguments.bool("include_app_audio") ?? false,
            includeMicrophone: arguments.bool("include_microphone") ?? false,
            showCursor: true,
            maxDurationSeconds: arguments.int("duration_seconds"),
            outputDirectory: outputDir,
            filename: arguments.string("filename")
        )

        do {
            try await RecordingSessionManager.shared.start(config: config)
        } catch let error as RecordingError {
            return RecordingToolSupport.describe(error, kernel: kernel)
        } catch {
            return ScreenRecorderLocalization.localized(
                kernel.language,
                en: "Failed to start recording: \(error.localizedDescription)",
                zh: "开始录制失败：\(error.localizedDescription)"
            )
        }

        let whereTo = config.outputDirectory.path
        return ScreenRecorderLocalization.localized(
            kernel.language,
            en: "Recording started. Output will be saved to \(whereTo). Tell me \"stop\" (or click the floating Stop button) when done.",
            zh: "已开始录制，结束后将保存到 \(whereTo)。完成后对我说「停」，或点屏幕顶部浮层的「停止」按钮。"
        )
    }
}
