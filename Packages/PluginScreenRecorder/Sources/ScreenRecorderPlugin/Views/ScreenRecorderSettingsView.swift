import AppKit
import SwiftUI

/// 屏幕录制设置页：权限状态、3 秒测试录制、行为说明。
@MainActor
struct ScreenRecorderSettingsView: View {
    @ObservedObject private var state: ScreenRecorderSettingsState
    @State private var screenRecordingAllowed = false
    @State private var microphoneAllowed = false
    @State private var revision = 0
    @State private var testing = false
    @State private var testMessage: String?

    init(state: ScreenRecorderSettingsState) {
        self._state = ObservedObject(wrappedValue: state)
    }

    var body: some View {
        Form {
            Section(ScreenRecorderLocalization.ui("Permissions", "权限")) {
                permissionRow(
                    title: ScreenRecorderLocalization.ui("Screen Recording", "屏幕录制"),
                    detail: ScreenRecorderLocalization.ui("Required to capture app windows or the screen.", "录制 app 窗口或屏幕所必需。"),
                    granted: screenRecordingAllowed,
                    request: {
                        RecordingPermissionService.requestScreenRecordingPermission()
                        RecordingPermissionService.openScreenRecordingSettings()
                        refresh()
                    }
                )
                permissionRow(
                    title: ScreenRecorderLocalization.ui("Microphone", "麦克风"),
                    detail: ScreenRecorderLocalization.ui("Only needed when recording your voice (include_microphone).", "仅在录制你的解说（include_microphone）时需要。"),
                    granted: microphoneAllowed,
                    request: {
                        RecordingPermissionService.requestMicrophonePermission { _ in Task { @MainActor in refresh() } }
                        RecordingPermissionService.openMicrophoneSettings()
                    }
                )
            }

            Section(ScreenRecorderLocalization.ui("Verification", "验证")) {
                Button {
                    runTestRecording()
                } label: {
                    Label(ScreenRecorderLocalization.ui("Record a 3-second test clip", "录制 3 秒测试片段"), systemImage: "record.circle")
                }
                .disabled(testing || !screenRecordingAllowed)
                if testing {
                    ProgressView().controlSize(.small)
                }
                if let testMessage {
                    Text(testMessage).font(.callout).foregroundStyle(.secondary)
                }
            }

            Section {
                Text(ScreenRecorderLocalization.ui(
                    "Recording captures a single app window by default and excludes Lumi itself. Output goes to ~/Downloads as .mp4. A floating indicator with a Stop button appears while recording; recordings auto-stop when the target window closes or the duration elapses.",
                    "默认录制单个 app 窗口，且不录制 Lumi 自身。输出为 .mp4 到 ~/Downloads。录制时会出现带「停止」按钮的浮层；目标窗口关闭或时长结束时会自动停止。"
                ))
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .id(revision)
        .onAppear(perform: refresh)
        .onChange(of: state.revision) { _, _ in refresh() }
    }

    @ViewBuilder
    private func permissionRow(title: String, detail: String, granted: Bool, request: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Label(
                granted ? ScreenRecorderLocalization.ui("Granted", "已授权") : ScreenRecorderLocalization.ui("Required", "需要授权"),
                systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
            )
            .foregroundStyle(granted ? .green : .orange)
            if !granted {
                Button(ScreenRecorderLocalization.ui("Grant Access", "去授权"), action: request)
            }
        }
    }

    private func refresh() {
        screenRecordingAllowed = RecordingPermissionService.hasScreenRecordingPermission
        microphoneAllowed = RecordingPermissionService.hasMicrophonePermission
        revision += 1
    }

    /// 3 秒整屏测试录制，验证引擎与落盘链路。
    private func runTestRecording() {
        guard !testing else { return }
        testing = true
        testMessage = nil
        Task {
            let config = RecordingConfig(
                target: .display(excludeLumi: true),
                maxDurationSeconds: 3,
                outputDirectory: RecordingToolSupport.defaultDownloadDirectory(),
                filename: "lumi-test"
            )
            do {
                try await RecordingSessionManager.shared.start(config: config)
                // 到点自动停止；轮询等待结束。
                while RecordingSessionManager.shared.hasActiveSession {
                    try? await Task.sleep(for: .milliseconds(200))
                    if Task.isCancelled { break }
                }
                if let result = RecordingSessionManager.shared.lastResult {
                    testMessage = ScreenRecorderLocalization.ui(
                        "Saved \(result.outputURL.lastPathComponent).",
                        "已保存 \(result.outputURL.lastPathComponent)。"
                    )
                }
            } catch {
                testMessage = error.localizedDescription
            }
            testing = false
            revision += 1
        }
    }
}
