import Foundation
import KernelLumi

/// `willSendToLLM` 钩子：在消息前注入一段系统提示，教会 LLM 录制工作流。
@MainActor
struct ScreenRecorderWillSendToLLMHook {
    func execute(kernel: KernelLumi, messages: [LumiChatMessage]) async -> [LumiChatMessage] {
        guard let conversationID = messages.last?.conversationID else { return messages }
        let guidance = LumiChatMessage(
            conversationID: conversationID,
            role: .system,
            content: """
            Screen recording tools are available: start_recording, stop_recording, list_recordable_apps. \
            Use them to record an app's usage flow into a video saved to ~/Downloads (by default). \
            Workflow: (1) clarify the target app, duration or stop trigger, whether to include audio/microphone, \
            the filename, and the output directory before recording; (2) if unsure which app, call list_recordable_apps; \
            (3) call start_recording (it prompts the user to confirm, then a floating indicator appears); \
            (4) tell the user recording has started and how to stop (say "stop" or click the floating Stop button); \
            (5) call stop_recording when done and report the saved file path, duration, and size. \
            For an automated demo, you may drive the app with computer_observe/computer_act while recording. \
            start_recording records a single app window by default (target="app_window"); use target="display" for the whole screen.
            """
        )
        return [guidance] + messages
    }
}
