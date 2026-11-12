import Foundation
import ProviderMessage
import Testing
@testable import PluginDevice

/// 设备状态卡片时间线消息的行为。
@Suite("DeviceStatusTimeline")
struct DeviceStatusTimelineTests {

    /// 造一份可预期的载荷，供各用例复用。
    static func makePayload(scope: DeviceStatusScope = .overview) -> DeviceStatusPayload {
        DeviceStatusPayload(
            scope: scope,
            timestamp: 1_700_000_000,
            device: DeviceIdentity(
                name: "Test Mac",
                osVersion: "macOS 15.1.0",
                processorName: "Apple M3 Pro",
                physicalCoreCount: 12,
                logicalCoreCount: 18,
                uptime: 86_400
            ),
            cpu: DeviceCPUStatus(
                usagePercentage: 42.5,
                perCoreUsage: [10, 20, 30],
                loadAverage: [1.5, 1.2, 1.0],
                userPercentage: 30,
                systemPercentage: 12.5,
                idlePercentage: 57.5
            ),
            memory: DeviceMemoryStatus(
                usagePercentage: 55,
                usedBytes: 18_000_000_000,
                totalBytes: 32_000_000_000,
                pressure: "Normal"
            ),
            gpu: DeviceGPUStatus(
                utilizationPercentage: 12,
                usedMemoryBytes: 1_000_000_000,
                totalMemoryBytes: 8_000_000_000,
                temperatureCelsius: 48,
                modelName: "Apple M3 Pro GPU"
            ),
            battery: DeviceBatteryStatus(
                level: 0.72,
                isCharging: true,
                isCharged: false,
                healthPercentage: 95,
                cycleCount: 120,
                temperatureCelsius: 30,
                watts: 8.5,
                hasBattery: true
            ),
            volumes: [
                DeviceVolumeStatus(
                    name: "Macintosh HD",
                    totalBytes: 1_000_000_000_000,
                    availableBytes: 400_000_000_000,
                    isInternal: true,
                    isEjectable: false
                )
            ],
            thermal: DeviceThermalStatus(
                readings: [DeviceThermalReading(index: 0, kind: "die", celsius: 52.5)],
                peakCelsius: 52.5
            ),
            processes: [
                DeviceProcessStatus(
                    pid: 42,
                    name: "Safari",
                    cpuPercentage: 12.5,
                    memoryBytes: 500_000_000,
                    instanceCount: 3,
                    isCurrentApp: false
                )
            ]
        )
    }

    @Test("载荷能通过 content 往返")
    func payloadRoundTripsThroughContent() {
        let original = Self.makePayload()

        let message = DeviceStatusTimeline.message(
            conversationID: UUID(),
            turnID: nil,
            payload: original
        )

        let decoded = DeviceStatusTimeline.decodePayload(from: message.content)
        #expect(decoded == original)
    }

    @Test("消息被标记为设备状态时间线事件")
    func messageIsMarkedAsTimelineEvent() {
        let message = DeviceStatusTimeline.message(
            conversationID: UUID(),
            turnID: nil,
            payload: Self.makePayload()
        )

        #expect(message.renderKind == MessageTimelineEvent.deviceStatusRenderKind)
        #expect(message.preferredRendererID == DeviceStatusTimeline.rendererID)
        #expect(message.role == .system)
        #expect(MessageTimelineEvent.isDeviceStatus(message))
    }

    /// 关键回归：设备状态卡片是纯界面产物，绝不能进入后续 LLM 上下文。
    ///
    /// 若 `isTimelineEvent` 漏掉了这一类型，卡片 JSON 会被当成对话历史
    /// 发给模型，既浪费 token 又让模型看到看不懂的内容。
    @Test("卡片被排除在 LLM 上下文之外")
    func cardIsExcludedFromLLMContext() {
        let message = DeviceStatusTimeline.message(
            conversationID: UUID(),
            turnID: nil,
            payload: Self.makePayload()
        )

        #expect(MessageTimelineEvent.isTimelineEvent(message))
    }

    @Test("损坏的 content 降级为 nil 而不是崩溃")
    func corruptedContentDegradesToNil() {
        #expect(DeviceStatusTimeline.decodePayload(from: "not json at all") == nil)
        #expect(DeviceStatusTimeline.decodePayload(from: "") == nil)
    }

    @Test("摘要文本对每个范围都可读")
    func summaryTextStaysReadable() {
        for scope in DeviceStatusScope.allCases {
            let summary = DeviceStatusTimeline.summaryText(for: Self.makePayload(scope: scope))
            #expect(!summary.isEmpty)
            #expect(summary.contains(scope.rawValue))
        }
    }

    @Test("会话与回合 ID 被写进消息")
    func messageCarriesConversationAndTurn() {
        let conversationID = UUID()
        let turnID = UUID()

        let message = DeviceStatusTimeline.message(
            conversationID: conversationID,
            turnID: turnID,
            payload: Self.makePayload()
        )

        #expect(message.conversationID == conversationID)
        #expect(message.turnID == turnID)
    }
}
