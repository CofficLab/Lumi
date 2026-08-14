import Foundation
import KernelLumi

/// `stop_recording`：停止当前录制并落盘，返回文件路径、时长与大小。
public struct StopRecordingTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "stop_recording",
        displayName: "Stop Recording",
        description: "Stop the active recording, encode it, and save the video to the output directory. Returns the file path, duration, and size."
    )

    public init() {}

    public var tags: Set<LumiToolTag> { [.sideEffect] }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel { .low }
    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "Stop recording" }

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:]),
            "additionalProperties": .bool(false),
        ])
    }

    @MainActor
    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        try kernel.checkCancellation()

        let result: RecordingResult
        do {
            result = try await RecordingSessionManager.shared.stop()
        } catch let error as RecordingError {
            return RecordingToolSupport.describe(error, kernel: kernel)
        } catch {
            return ScreenRecorderLocalization.localized(
                kernel.language,
                en: "Failed to stop recording: \(error.localizedDescription)",
                zh: "停止录制失败：\(error.localizedDescription)"
            )
        }

        let mb = Double(result.fileSizeBytes) / 1_000_000
        let path = result.outputURL.path
        return ScreenRecorderLocalization.localized(
            kernel.language,
            en: "Saved \(path) (\(result.durationSeconds)s, \(result.width)×\(result.height), \(String(format: "%.1f", mb)) MB).",
            zh: "已保存到 \(path)（\(result.durationSeconds) 秒，\(result.width)×\(result.height)，\(String(format: "%.1f", mb)) MB）。"
        )
    }
}
