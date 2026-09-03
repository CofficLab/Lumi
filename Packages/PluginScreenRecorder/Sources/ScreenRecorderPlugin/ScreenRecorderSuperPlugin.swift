import KitAgentTool
import Foundation
import KernelCore
import ProviderDocsView
import ProviderSettingView
import ProviderStorage
import ProviderToolManager
import KitSuperLog
import os

@MainActor
public final class ScreenRecorderSuperPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.screen-recorder", category: "ScreenRecorder")
    public let id = "com.coffic.lumi.plugin.screen-recorder"
    public let order = 285
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.screen-recorder",
        name: ScreenRecorderLocalization.string("Screen Recorder", "屏幕录制"),
        description: ScreenRecorderLocalization.string("Record an app window or display to a video file through chat.", "通过对话将应用窗口或屏幕录制为视频文件。"),
        category: .integration,
        stage: .preview,
        policy: .disabledByDefault
    )

    private var settingsState: ScreenRecorderSettingsState?
    private var activationObserver: ApplicationActivationObserver?
    private var recordingObserver: RecordingSessionObserver?

    public init() {}

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) { ScreenRecorderAboutView() })
            docs.addManual(DocsEntry(id: id, name: metadata.name) { ScreenRecorderManualView() })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        let dataDirectory = kernel.resolveProvider((any StorageProviding).self)?
            .pluginDataDirectory(for: "ScreenRecorder")
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("ScreenRecorder", isDirectory: true)
        ScreenRecorderRuntime.configure(dataDirectory: dataDirectory)
        let settingsState = ScreenRecorderSettingsState()
        self.settingsState = settingsState
        activationObserver = ApplicationActivationObserver { [weak settingsState] in
            settingsState?.refresh()
        }
        recordingObserver = RecordingSessionObserver(manager: .shared) { activity in
            switch activity.state {
            case .recording:
                if let description = activity.targetDescription {
                    RecordingIndicatorController.shared.show(description: description)
                }
                RecordingIndicatorController.shared.update(elapsed: activity.elapsedSeconds)
            case .stopping:
                RecordingIndicatorController.shared.update(elapsed: activity.elapsedSeconds)
            case .finished, .error, .idle:
                RecordingIndicatorController.shared.hide()
            }
        }

        let tools = kernel.resolveProvider((any ToolManagerProviding).self)
        tools?.add(StartRecordingV2Tool(), pluginID: id)
        tools?.add(StopRecordingV2Tool(), pluginID: id)
        tools?.add(ListRecordableAppsV2Tool(), pluginID: id)

        kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([
            SettingEntryItem(id: "\(id).settings", title: metadata.name, systemImage: "record.circle", order: order) {
                ScreenRecorderSettingsView(state: settingsState)
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        let tools = kernel.resolveProvider((any ToolManagerProviding).self)
        [StartRecordingV2Tool.toolName, StopRecordingV2Tool.toolName, ListRecordableAppsV2Tool.toolName].forEach {
            tools?.remove(id: $0)
        }
        activationObserver?.cancel()
        activationObserver = nil
        recordingObserver?.cancel()
        recordingObserver = nil
        settingsState = nil
        ScreenRecorderRuntime.reset()
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: ["\(id).settings"])
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}

public struct StartRecordingV2Tool: SuperAgentTool {
    public static let toolName = "start_recording"
    public let name = toolName
    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Start recording an app window or the display. Before calling, confirm the target, audio options, filename, and output directory with the user. The default output is ~/Downloads."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": [
            "application": ["type": "string", "description": "Target app name or bundle identifier. Required for app_window."],
            "window_title": ["type": "string"],
            "target": ["type": "string", "enum": ["app_window", "display"], "default": "app_window"],
            "duration_seconds": ["type": "integer", "minimum": 1, "maximum": 3600],
            "include_app_audio": ["type": "boolean", "default": false],
            "include_microphone": ["type": "boolean", "default": false],
            "frame_rate": ["type": "integer", "default": 30],
            "resolution_height": ["type": "integer"],
            "output_directory": ["type": "string"],
            "filename": ["type": "string"],
        ], "additionalProperties": false]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "录制 \(ScreenRecorderV2Support.string(arguments, "application") ?? "屏幕")"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .high }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let targetKind = ScreenRecorderV2Support.string(arguments, "target") ?? "app_window"
        let application = ScreenRecorderV2Support.string(arguments, "application") ?? ""
        let target: RecordingTarget
        if targetKind == "display" {
            target = .display(excludeLumi: true)
        } else {
            guard !application.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return "No visible-window application was specified."
            }
            target = .appWindow(application: application, windowTitle: ScreenRecorderV2Support.string(arguments, "window_title"))
        }
        let outputDirectory = ScreenRecorderV2Support.outputDirectory(arguments)
        let config = RecordingConfig(
            target: target,
            frameRate: ScreenRecorderV2Support.integer(arguments, "frame_rate") ?? 30,
            resolutionHeight: ScreenRecorderV2Support.integer(arguments, "resolution_height"),
            includeAppAudio: ScreenRecorderV2Support.boolean(arguments, "include_app_audio"),
            includeMicrophone: ScreenRecorderV2Support.boolean(arguments, "include_microphone"),
            maxDurationSeconds: ScreenRecorderV2Support.integer(arguments, "duration_seconds"),
            outputDirectory: outputDirectory,
            filename: ScreenRecorderV2Support.string(arguments, "filename")
        )
        do {
            try await RecordingSessionManager.shared.start(config: config)
            return "Recording started. Output will be saved to \(outputDirectory.path). Say stop or use the floating Stop button when finished."
        } catch let error as RecordingError {
            return await ScreenRecorderV2Support.describe(error)
        } catch {
            return "Failed to start recording: \(error.localizedDescription)"
        }
    }
}

public struct StopRecordingV2Tool: SuperAgentTool {
    public static let toolName = "stop_recording"
    public let name = toolName
    public init() {}
    public func description(for language: LanguagePreference) -> String { "Stop the active recording and save the video file." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object", "properties": [:], "additionalProperties": false] }
    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "停止录制" }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        do {
            let result = try await RecordingSessionManager.shared.stop()
            let megabytes = Double(result.fileSizeBytes) / 1_000_000
            return "Saved \(result.outputURL.path) (\(result.durationSeconds)s, \(result.width)×\(result.height), \(String(format: "%.1f", megabytes)) MB)."
        } catch let error as RecordingError {
            return await ScreenRecorderV2Support.describe(error)
        } catch {
            return "Failed to stop recording: \(error.localizedDescription)"
        }
    }
}

public struct ListRecordableAppsV2Tool: SuperAgentTool {
    public static let toolName = "list_recordable_apps"
    public let name = toolName
    public init() {}
    public func description(for language: LanguagePreference) -> String { "List visible app windows that can be selected as recording targets." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object", "properties": ["filter": ["type": "string"]], "additionalProperties": false] }
    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "列出可录制应用" }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .safe }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let filter = ScreenRecorderV2Support.string(arguments, "filter")?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let windows = await MainActor.run { RecordableWindowProvider.availableWindows() }
        let lines = windows.filter { window in
            guard let filter, !filter.isEmpty else { return true }
            return window.applicationName.lowercased().contains(filter) || window.bundleIdentifier.lowercased().contains(filter)
        }.map { window in
            let title = window.windowTitle.isEmpty ? "" : " — \(window.windowTitle)"
            return "- \(window.applicationName) (\(window.bundleIdentifier))\(title) — \(Int(window.frame.width))×\(Int(window.frame.height))"
        }
        return lines.isEmpty ? "No recordable apps found." : "Recordable apps:\n\(lines.joined(separator: "\n"))"
    }
}

private enum ScreenRecorderV2Support {
    static func string(_ arguments: [String: ToolArgument], _ key: String) -> String? {
        guard let value = arguments[key]?.value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func integer(_ arguments: [String: ToolArgument], _ key: String) -> Int? {
        if let value = arguments[key]?.value as? Int { return value }
        if let value = arguments[key]?.value as? NSNumber { return value.intValue }
        return nil
    }

    static func boolean(_ arguments: [String: ToolArgument], _ key: String) -> Bool {
        if let value = arguments[key]?.value as? Bool { return value }
        if let value = arguments[key]?.value as? NSNumber { return value.boolValue }
        return false
    }

    static func outputDirectory(_ arguments: [String: ToolArgument]) -> URL {
        let raw = string(arguments, "output_directory") ?? RecordingToolSupport.defaultDownloadDirectory().path
        return URL(fileURLWithPath: (raw as NSString).expandingTildeInPath, isDirectory: true).standardizedFileURL
    }

    @MainActor static func describe(_ error: RecordingError) -> String {
        switch error {
        case .permissionDenied:
            RecordingPermissionService.openScreenRecordingSettings()
            return "Screen Recording permission is required. System Settings has been opened."
        case .microphonePermissionDenied:
            RecordingPermissionService.openMicrophoneSettings()
            return "Microphone permission is required. System Settings has been opened."
        default:
            return error.errorDescription ?? "Unknown recording error."
        }
    }
}
