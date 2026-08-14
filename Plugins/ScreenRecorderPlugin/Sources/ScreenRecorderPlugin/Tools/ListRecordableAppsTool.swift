import Foundation
import KernelLumi

/// `list_recordable_apps`：列出当前带可见窗口的 app，供 LLM 消歧与选择录制目标。
public struct ListRecordableAppsTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "list_recordable_apps",
        displayName: "List Recordable Apps",
        description: "List apps with visible on-screen windows, to help pick or disambiguate a recording target. Returns name, bundle id, window title, and size."
    )

    public init() {}

    public var tags: Set<LumiToolTag> { [.readOnly, .fast] }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel { .safe }
    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "List recordable apps" }

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "filter": .object(["type": .string("string"), "description": .string("Optional substring to filter app names/bundle ids.")]),
            ]),
            "additionalProperties": .bool(false),
        ])
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        try kernel.checkCancellation()
        let filter = arguments.string("filter")?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let windows = await MainActor.run { RecordableWindowProvider.availableWindows() }
        let lines = windows
            .filter { window in
                guard let filter else { return true }
                return window.applicationName.lowercased().contains(filter)
                    || window.bundleIdentifier.lowercased().contains(filter)
            }
            .map { window -> String in
                let title = window.windowTitle.isEmpty ? "" : " — \(window.windowTitle)"
                return "- \(window.applicationName) (\(window.bundleIdentifier))\(title) — \(Int(window.frame.width))×\(Int(window.frame.height))"
            }

        guard !lines.isEmpty else {
            return ScreenRecorderLocalization.localized(
                kernel.language,
                en: "No recordable apps found.",
                zh: "没有找到可录制的 app。"
            )
        }
        return (ScreenRecorderLocalization.localized(kernel.language, en: "Recordable apps:", zh: "可录制的 app：") + "\n" + lines.joined(separator: "\n"))
    }
}
