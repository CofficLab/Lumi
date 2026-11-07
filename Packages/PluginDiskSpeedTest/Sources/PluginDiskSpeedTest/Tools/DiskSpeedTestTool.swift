import Foundation
import KitAgentTool
import os

/// 在聊天消息区执行磁盘测速的工具。
///
/// LLM 调用本工具后：
/// 1. 工具立即插入一条 `renderKind = "disk-speed"` 的时间线消息，
///    卡片显示「正在测试硬盘速度…」；
/// 2. 工具在后台完成真实的顺序读写测速；
/// 3. 测速结束后更新同一条消息，把卡片推进为「读 1.2 GB/s，写 900 MB/s」。
///
/// 卡片消息只用于界面展示，不会回流到 LLM 上下文。
///
/// ## 为什么卡片先插入、结果后回填
///
/// 测速本身要写入数百 MB 数据、耗时数秒。若等测速完成才插入卡片，
/// 用户在这段时间里看不到任何反馈，会以为工具卡死。
/// 先插「进行中」卡片、测完再更新，是长耗时操作的标准反馈模式。
public struct DiskSpeedTestTool: SuperAgentTool, @unchecked Sendable {
    /// 工具名（唯一标识符，不翻译）。
    public static let toolName = "disk_speed_test"

    public let name = Self.toolName

    /// 插入与更新卡片消息的桥。由插件在 `onBoot` 时创建并注入。
    private let bridge: DiskSpeedMessageBridge

    /// 执行测速的服务。
    private let tester: DiskSpeedTester

    /// 测速文件所在的目录。由插件在 `onBoot` 时从 `StorageProviding` 注入。
    private let workingDirectory: URL

    public init(
        bridge: DiskSpeedMessageBridge,
        tester: DiskSpeedTester = DiskSpeedTester(),
        workingDirectory: URL
    ) {
        self.bridge = bridge
        self.tester = tester
        self.workingDirectory = workingDirectory
    }

    public func description(for language: LanguagePreference) -> String {
        "Measure disk sequential read and write speed by writing and reading a temporary file. Use this when the user asks how fast the disk is, wants a speed test, or asks about disk performance."
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "测试硬盘速度"
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [:],
            "required": [],
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        // 读写的是插件自己数据目录下的临时文件，测完即删，
        // 不会触碰用户的文件，因此风险很低。
        .low
    }

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
    /// 让用户在测速过程中就能看到进度卡片。
    /// 时间线消息只用于界面展示，不会回流到 LLM 上下文。
    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        try await run(
            arguments: arguments,
            timeline: DiskSpeedTimelineContext(
                conversationID: context.conversationID,
                turnID: context.turnID
            )
        )
    }

    // MARK: - Core

    /// 工具的核心流程。
    ///
    /// - Parameters:
    ///   - arguments: 工具参数。
    ///   - timeline: 会话上下文；为 nil 时不产生时间线消息。
    /// - Returns: 工具结果。
    private func run(
        arguments: [String: ToolArgument],
        timeline: DiskSpeedTimelineContext?
    ) async throws -> ToolCallResult {
        let directory = workingDirectory.path

        // 1) 先插「进行中」卡片，让用户立刻看到反馈。
        var cardMessageID: UUID?
        if let timeline {
            cardMessageID = await MainActor.run {
                bridge.insert(
                    conversationID: timeline.conversationID,
                    turnID: timeline.turnID,
                    payload: .running(directory: directory)
                )
            }
        }

        // 2) 执行真实测速。
        let result: Result<(write: DiskSpeedTester.Measurement, read: DiskSpeedTester.Measurement), Error>
        do {
            let measurements = try await tester.measure(in: workingDirectory)
            result = .success(measurements)
        } catch {
            result = .failure(error)
        }

        // 3) 回填卡片状态。
        if let timeline, let cardMessageID {
            let payload: DiskSpeedPayload
            let toolContent: String
            switch result {
            case .success(let measurements):
                payload = DiskSpeedPayload(
                    phase: .finished,
                    readBytesPerSecond: measurements.read.bytesPerSecond,
                    writeBytesPerSecond: measurements.write.bytesPerSecond,
                    readBytes: measurements.read.bytes,
                    writeBytes: measurements.write.bytes
                )
                toolContent = Self.summary(for: payload)
            case .failure(let error):
                payload = .failed(directory: directory, reason: error.localizedDescription)
                toolContent = "Disk speed test failed: \(error.localizedDescription)"
            }

            await MainActor.run {
                bridge.update(
                    messageID: cardMessageID,
                    conversationID: timeline.conversationID,
                    payload: payload
                )
            }
            return ToolCallResult(content: toolContent)
        }

        // 没有会话上下文（拿不到卡片）时，只把结果返回给 LLM。
        switch result {
        case .success(let measurements):
            return ToolCallResult(content: Self.summary(for: DiskSpeedPayload(
                phase: .finished,
                readBytesPerSecond: measurements.read.bytesPerSecond,
                writeBytesPerSecond: measurements.write.bytesPerSecond,
                readBytes: measurements.read.bytes,
                writeBytes: measurements.write.bytes
            )))
        case .failure(let error):
            throw error
        }
    }

    /// 生成给 LLM 的结果文本。
    private static func summary(for payload: DiskSpeedPayload) -> String {
        let read = payload.displayReadSpeed ?? "n/a"
        let write = payload.displayWriteSpeed ?? "n/a"
        let size = DiskSpeedPayload.formattedBytes(payload.readBytes)
        return "Disk speed test completed on \(size) sample. Read: \(read). Write: \(write)."
    }
}

/// 磁盘测速卡片时间线消息的会话上下文。
///
/// 工具只有在拿到真实会话信息时才插入时间线消息；拿不到就不插入，
/// 避免把消息写进一个不存在的会话。
struct DiskSpeedTimelineContext: Sendable {
    let conversationID: UUID
    let turnID: UUID?

    init(conversationID: UUID, turnID: UUID?) {
        self.conversationID = conversationID
        self.turnID = turnID
    }
}
