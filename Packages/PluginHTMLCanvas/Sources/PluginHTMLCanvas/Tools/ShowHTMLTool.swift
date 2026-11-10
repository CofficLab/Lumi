import Foundation
import KitAgentTool

/// 在聊天消息区显示一张 HTML 界面卡片的工具。
///
/// LLM 调用本工具后：
/// 1. 工具把 HTML 落盘成文件，并预渲染一张 PNG 快照；
/// 2. 插件插入一条带 `renderKind = "html-canvas"` 的时间线消息；
/// 3. 插件注册的渲染器把这条消息画成一张卡片（标题 + 界面预览）。
///
/// HTML 本身**不会**回传给 LLM 上下文——这条消息只是给人看的界面产物。
public struct ShowHTMLTool: SuperAgentTool, @unchecked Sendable {
    /// 工具名（唯一标识符，不翻译）。
    public static let toolName = "show_html"

    public let name = Self.toolName

    /// 插入卡片消息的桥。由插件在 `onBoot` 时创建并注入。
    private let bridge: HTMLCanvasMessageBridge

    /// HTML 与快照的落盘目录。由插件在 `onBoot` 时注入。
    private let storageDirectory: URL

    public init(bridge: HTMLCanvasMessageBridge, storageDirectory: URL) {
        self.bridge = bridge
        self.storageDirectory = storageDirectory
    }

    public func description(for language: LanguagePreference) -> String {
        "Render an HTML interface in the chat. Provide a complete HTML document and it will be displayed as a card below your message. Use this when you want to show the user a UI — a chart, a diagram, a mockup, a report layout. The HTML is not sent back to the model."
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let title = Self.string(from: arguments, key: "title"), !title.isEmpty else {
            return "显示 HTML 界面"
        }
        return "显示 HTML 界面：\(title)"
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "html": [
                    "type": "string",
                    "description": "Complete HTML document to display. Include <!DOCTYPE html>, <html>, <head> and <body>. Inline all CSS and JavaScript; do not reference external stylesheets.",
                ],
                "title": [
                    "type": "string",
                    "description": "Optional card title shown above the rendered interface.",
                ],
                "width": [
                    "type": "number",
                    "description": "Design canvas width in CSS pixels. Defaults to 800.",
                ],
                "height": [
                    "type": "number",
                    "description": "Design canvas height in CSS pixels. Defaults to 600.",
                ],
            ],
            "required": ["html"],
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        // 只写插件自己的数据目录并渲染一张图片，不触碰用户项目文件。
        .low
    }

    /// HTML 原文已经落盘并渲染在聊天里，后续回合只保留其余参数。
    public var contextOmittedArgumentKeys: Set<String> { ["html"] }

    /// 无会话上下文的执行入口。
    ///
    /// 拿不到会话信息时不插入时间线消息——避免把消息写进一个不存在的会话里。
    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        try await run(arguments: arguments, timeline: nil).content
    }

    public func executeResult(arguments: [String: ToolArgument]) async throws -> ToolCallResult {
        try await run(arguments: arguments, timeline: nil)
    }

    /// 带会话上下文的结构化执行入口。
    ///
    /// 借 `ToolExecutionContext` 拿到会话与回合 ID，插入一条结构化时间线消息，
    /// 让用户直接看到界面。时间线消息只用于界面展示，不会回流到 LLM 上下文。
    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        try await run(
            arguments: arguments,
            timeline: HTMLCanvasTimelineContext(
                conversationID: context.conversationID,
                turnID: context.turnID
            ),
            isCancelled: context.isCancelled
        )
    }

    // MARK: - Core

    /// 工具的核心流程。
    ///
    /// - Parameters:
    ///   - arguments: 工具参数。
    ///   - timeline: 会话上下文；为 nil 时不产生时间线消息。
    ///   - isCancelled: 执行层的取消查询。
    /// - Returns: 工具结果。
    private func run(
        arguments: [String: ToolArgument],
        timeline: HTMLCanvasTimelineContext?,
        isCancelled: @Sendable () -> Bool = { false }
    ) async throws -> ToolCallResult {
        try Self.checkCancellation(isCancelled)

        guard let html = Self.string(from: arguments, key: "html"),
              !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ToolCallResult(
                content: "Missing or empty html. Provide a complete HTML document to display.",
                isError: true
            )
        }

        let title = Self.string(from: arguments, key: "title") ?? ""
        let width = Self.double(from: arguments, key: "width") ?? Self.defaultWidth
        let height = Self.double(from: arguments, key: "height") ?? Self.defaultHeight

        let payload: HTMLCanvasPayload
        do {
            payload = try await HTMLCanvasStore.persist(
                html: html,
                title: title,
                width: width,
                height: height,
                directory: storageDirectory
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return ToolCallResult(
                content: "Failed to render the HTML interface: \(error.localizedDescription)",
                isError: true
            )
        }

        // 取消后不能留下可见副作用：落盘文件与时间线卡片都视为未发生。
        guard !Self.isCancellationRequested(isCancelled) else {
            Self.discard(payload)
            throw CancellationError()
        }

        if let timeline {
            let inserted = await MainActor.run {
                guard !Self.isCancellationRequested(isCancelled) else { return false }
                bridge.insert(
                    conversationID: timeline.conversationID,
                    turnID: timeline.turnID,
                    payload: payload
                )
                return true
            }
            guard inserted else {
                Self.discard(payload)
                throw CancellationError()
            }
        }

        return ToolCallResult(
            content: "HTML interface displayed in the chat (\(Int(width))x\(Int(height))). The user can see it rendered below your message."
        )
    }

    // MARK: - Cancellation

    private static func isCancellationRequested(_ isCancelled: @Sendable () -> Bool) -> Bool {
        Task.isCancelled || isCancelled()
    }

    private static func checkCancellation(_ isCancelled: @Sendable () -> Bool) throws {
        if isCancellationRequested(isCancelled) {
            throw CancellationError()
        }
    }

    /// 删除尚未发布到时间线的产物。
    private static func discard(_ payload: HTMLCanvasPayload) {
        for path in [payload.htmlPath, payload.snapshotPath] where !path.isEmpty {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    // MARK: - Arguments

    /// 默认画布宽度（CSS 逻辑像素）。
    static let defaultWidth: Double = 800

    /// 默认画布高度（CSS 逻辑像素）。
    static let defaultHeight: Double = 600

    /// 画布尺寸的合法区间。
    ///
    /// 超出这个范围时钳制到边界：过小的画布渲染出来是空白，
    /// 过大的画布会让快照 PNG 体积失控。
    static let minCanvasSize: Double = 200
    static let maxCanvasSize: Double = 4096

    /// 读取一个字符串参数并去掉首尾空白。
    ///
    /// 参数缺失或为空白时返回 nil，让调用方决定回退策略。
    static func string(from arguments: [String: ToolArgument], key: String) -> String? {
        guard let value = arguments[key]?.value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 读取一个数值参数并钳制到合法区间。
    ///
    /// 非数值、缺失或非有限时返回 nil，由调用方使用缺省值。
    static func double(from arguments: [String: ToolArgument], key: String) -> Double? {
        let raw: Double?
        if let value = arguments[key]?.value as? Double {
            raw = value
        } else if let value = arguments[key]?.value as? Int {
            raw = Double(value)
        } else if let value = arguments[key]?.value as? String,
                  let parsed = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
            raw = parsed
        } else {
            raw = nil
        }

        guard let raw, raw.isFinite else { return nil }
        return min(max(raw, minCanvasSize), maxCanvasSize)
    }
}

/// HTML 卡片时间线消息的会话上下文。
///
/// 工具只有在拿到真实会话信息时才插入时间线消息；拿不到就不插入，
/// 避免把消息写进一个不存在的会话。
struct HTMLCanvasTimelineContext: Sendable {
    let conversationID: UUID
    let turnID: UUID?

    init(conversationID: UUID, turnID: UUID?) {
        self.conversationID = conversationID
        self.turnID = turnID
    }
}
