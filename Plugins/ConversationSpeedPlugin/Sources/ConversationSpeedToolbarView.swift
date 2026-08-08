import LumiKernel
import SwiftUI
import LocalizationKit

struct ConversationSpeedToolbarView: View {
    // selectedConversationID 由 .onLumiSelectedConversationDidChange 事件更新；
    // 消息变更由 .onLumiMessagesDidChange 精确覆盖。
    // 不挂 kernel 全局总线，project/settings 等无关服务变更不会触发这里刷新。
    let kernel: LumiKernel
    @State private var selectedConversationID: UUID?

    @State private var cachedTPS: Double?
    @State private var unavailabilityReason: ConversationSpeedUnavailability = .waitingForResponse
    @State private var popoverShown = false
    @State private var speedHistory: [ConversationSpeedSample] = []

    // Detail data shown inside the popover.
    @State private var modelName: String?
    @State private var outputTokens: Int?
    @State private var streamingDurationMs: Double?
    @State private var timeToFirstTokenMs: Double?
    @State private var providerID: String?

    var body: some View {
        Group {
            if selectedConversationID != nil {
                Button {
                    popoverShown.toggle()
                } label: {
                    HStack(spacing: ToolbarMetrics.chipSpacing) {
                        Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                            .font(.system(size: ToolbarMetrics.chipIconSize, weight: .medium))
                        Text(speedLabel)
                            .font(.system(size: ToolbarMetrics.chipTextSize, weight: ToolbarMetrics.chipTextWeight))
                            .contentTransition(.numericText())
                    }
                    .foregroundColor(cachedTPS == nil ? .secondary : .orange)
                    .padding(.horizontal, ToolbarMetrics.chipHorizontalPadding)
                    .padding(.vertical, ToolbarMetrics.chipVerticalPadding)
                    .background(
                        cachedTPS == nil ? Color.secondary.opacity(0.12) : Color.orange.opacity(0.22),
                        in: RoundedRectangle(cornerRadius: ToolbarMetrics.chipCornerRadius, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .help(LumiPluginLocalization.string("Streaming speed help", bundle: .module))
                .popover(isPresented: $popoverShown, arrowEdge: .bottom) {
                    ConversationSpeedPopover(
                        tps: cachedTPS,
                        unavailabilityReason: unavailabilityReason,
                        modelName: modelName,
                        outputTokens: outputTokens,
                        streamingDurationMs: streamingDurationMs,
                        timeToFirstTokenMs: timeToFirstTokenMs,
                        providerID: providerID,
                        speedHistory: speedHistory
                    )
                    .frame(width: 360)
                }
            } else {
                EmptyView()
            }
        }
        .onLumiMessagesDidChange { eventConversationID in
            guard eventConversationID == nil
                || eventConversationID == selectedConversationID else { return }
            self.updateTPS()
        }
        .onAppear {
            self.updateTPS()
        }
        .onChange(of: selectedConversationID) { oldValue, newValue in
            // 切换会话时重算速度（消息变更由 onLumiMessagesDidChange 覆盖）。
            if oldValue != newValue {
                resetDisplayState()
            }
            if newValue == nil {
                popoverShown = false
            }
            self.updateTPS()
        }
        .task {
            selectedConversationID = kernel.conversations?.selectedConversationID
        }
        .onLumiSelectedConversationDidChange { newID in
            selectedConversationID = newID
        }
    }

    private var speedLabel: String {
        guard let cachedTPS else {
            return LumiPluginLocalization.string("Speed unavailable", bundle: .module)
        }
        return String(format: "%.1f tok/s", cachedTPS)
    }

    private func resetDisplayState() {
        cachedTPS = nil
        unavailabilityReason = .waitingForResponse
        speedHistory = []
        modelName = nil
        outputTokens = nil
        streamingDurationMs = nil
        timeToFirstTokenMs = nil
        providerID = nil
    }

    private func updateTPS() {
        guard let conversationID = selectedConversationID else {
            if ConversationSpeedPlugin.verbose {
                ConversationSpeedPlugin.logger.info("\(ConversationSpeedPlugin.t)No selected conversation ID")
            }
            return
        }

        guard let messageManager = kernel.messageManager else {
            return
        }

        let messages = messageManager.messages(for: conversationID)
        let history = ConversationSpeedSample.samples(from: messages)
        speedHistory = history

        guard let lastMessage = messages.last ?? messageManager.lastMessage(in: conversationID) else {
            cachedTPS = nil
            unavailabilityReason = .waitingForResponse
            if ConversationSpeedPlugin.verbose {
                ConversationSpeedPlugin.logger.info("\(ConversationSpeedPlugin.t)No last message for conversation \(conversationID.uuidString.prefix(8))")
            }
            return
        }
        let latestAssistantMessage = messages.last(where: { $0.role == .assistant })
        let latestSpeedMessage = history.last?.message ?? latestAssistantMessage ?? lastMessage

        // Capture detail data for the popover.
        modelName = latestSpeedMessage.modelName
        outputTokens = latestSpeedMessage.outputTokenCount ?? Int(latestSpeedMessage.metadata["outputTokens"] ?? "")
        streamingDurationMs = latestSpeedMessage.conversationSpeedDurationMs
        timeToFirstTokenMs = latestSpeedMessage.timeToFirstTokenMs ?? Double(latestSpeedMessage.metadata["timeToFirstTokenMs"] ?? "")
        providerID = latestSpeedMessage.providerID

        // Prefer the effective duration-based value. A provider may deliver the
        // whole response in one chunk, making the post-first-token duration only
        // a few milliseconds even though the user waited several seconds.
        if let tps = history.last?.tokensPerSecond ?? lastMessage.conversationSpeedTokensPerSecond {
            if ConversationSpeedPlugin.verbose {
                ConversationSpeedPlugin.logger.info("\(ConversationSpeedPlugin.t)tokensPerSecond from property: \(tps)")
            }
            cachedTPS = tps
            return
        }

        cachedTPS = nil
        unavailabilityReason = ConversationSpeedUnavailability.reason(for: latestAssistantMessage)
        if ConversationSpeedPlugin.verbose {
            ConversationSpeedPlugin.logger.info("\(ConversationSpeedPlugin.t)Cannot calculate TPS: \(self.unavailabilityReason.rawValue)")
        }
    }
}

enum ConversationSpeedUnavailability: String, Equatable {
    case waitingForResponse
    case missingOutputTokens
    case missingDuration
    case missingOutputTokensAndDuration

    static func reason(for message: LumiChatMessage?) -> ConversationSpeedUnavailability {
        guard let message else { return .waitingForResponse }

        let outputTokens = message.outputTokenCount
            ?? Int(message.metadata["outputTokens"] ?? "")
        let duration = message.conversationSpeedDurationMs.flatMap { $0 > 0 ? $0 : nil }

        switch (outputTokens, duration) {
        case (nil, nil):
            return .missingOutputTokensAndDuration
        case (nil, _):
            return .missingOutputTokens
        case (_, nil):
            return .missingDuration
        case (.some(_), .some(_)):
            return .waitingForResponse
        }
    }

    var localizedExplanation: String {
        let key: String
        switch self {
        case .waitingForResponse:
            key = "Speed unavailable waiting for response"
        case .missingOutputTokens:
            key = "Speed unavailable missing output tokens"
        case .missingDuration:
            key = "Speed unavailable missing duration"
        case .missingOutputTokensAndDuration:
            key = "Speed unavailable missing output tokens and duration"
        }
        return LumiPluginLocalization.string(key, bundle: .module)
    }
}

struct ConversationSpeedSample: Identifiable, Equatable {
    let id: UUID
    let index: Int
    let createdAt: Date
    let tokensPerSecond: Double
    let message: LumiChatMessage

    static func samples(from messages: [LumiChatMessage]) -> [ConversationSpeedSample] {
        messages
            .sorted { $0.createdAt < $1.createdAt }
            .compactMap { message -> (Date, Double, LumiChatMessage)? in
                guard let tps = message.conversationSpeedTokensPerSecond else { return nil }
                return (message.createdAt, tps, message)
            }
            .enumerated()
            .map { offset, sample in
                ConversationSpeedSample(
                    id: sample.2.id,
                    index: offset,
                    createdAt: sample.0,
                    tokensPerSecond: sample.1,
                    message: sample.2
                )
            }
    }

    static func averageTokensPerSecond(from samples: [ConversationSpeedSample]) -> Double? {
        guard !samples.isEmpty else { return nil }
        let total = samples.reduce(0) { $0 + $1.tokensPerSecond }
        return total / Double(samples.count)
    }
}

private extension LumiChatMessage {
    /// Duration used for the user-facing speed metric.
    ///
    /// `streamingDurationMs` starts at the first token. When a provider buffers
    /// the response and delivers it in one chunk, that value can be nearly zero.
    /// The full request latency better represents the speed perceived by the
    /// user in that case.
    var conversationSpeedDurationMs: Double? {
        let streamingDuration = streamingDurationMs
            ?? Double(metadata["streamingDurationMs"] ?? "")
        let latency = latencyMs
            ?? Double(metadata["latencyMs"] ?? "")

        switch (streamingDuration, latency) {
        case let (streaming?, latency?) where streaming > 0 && latency > 0:
            return max(streaming, latency)
        case let (streaming?, _) where streaming > 0:
            return streaming
        case let (_, latency?) where latency > 0:
            return latency
        default:
            return nil
        }
    }

    var conversationSpeedTokensPerSecond: Double? {
        let outputTokens = outputTokenCount
            ?? Int(metadata["outputTokens"] ?? "")
        guard let outputTokens,
              let durationMs = conversationSpeedDurationMs,
              durationMs > 0 else {
            return nil
        }
        return Double(outputTokens) / (durationMs / 1000.0)
    }
}

// MARK: - Popover

private struct ConversationSpeedPopover: View {
    let tps: Double?
    let unavailabilityReason: ConversationSpeedUnavailability
    let modelName: String?
    let outputTokens: Int?
    let streamingDurationMs: Double?
    let timeToFirstTokenMs: Double?
    let providerID: String?
    let speedHistory: [ConversationSpeedSample]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .font(.system(size: 18))
                    .foregroundStyle(.orange)
                Text(LumiPluginLocalization.string("Streaming Speed", bundle: .module))
                    .font(.headline)
                Spacer()
            }

            if let tps {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", tps))
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                    Text(LumiPluginLocalization.string("tokens / second", bundle: .module))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                averageSpeedBlock

                Text(LumiPluginLocalization.string("Streaming speed description", bundle: .module))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                unavailableBlock
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                if let modelName, !modelName.isEmpty {
                    detailRow(
                        LumiPluginLocalization.string("Model", bundle: .module),
                        value: modelName
                    )
                }
                if let outputTokens {
                    detailRow(
                        LumiPluginLocalization.string("Output tokens", bundle: .module),
                        value: "\(outputTokens)"
                    )
                }
                if let streamingDurationMs {
                    detailRow(
                        LumiPluginLocalization.string("Streaming duration", bundle: .module),
                        value: formatDuration(streamingDurationMs)
                    )
                }
                if let timeToFirstTokenMs {
                    detailRow(
                        LumiPluginLocalization.string("Time to first token", bundle: .module),
                        value: formatDuration(timeToFirstTokenMs)
                    )
                }
                if let providerID, !providerID.isEmpty {
                    detailRow(
                        LumiPluginLocalization.string("Provider", bundle: .module),
                        value: providerID
                    )
                }
            }

            speedHistorySection

            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var unavailableBlock: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(LumiPluginLocalization.string("Speed unavailable", bundle: .module))
                    .font(.subheadline.weight(.semibold))
                Text(unavailabilityReason.localizedExplanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }

    private func formatDuration(_ ms: Double) -> String {
        if ms >= 1000 {
            return String(format: "%.2f s", ms / 1000.0)
        }
        return String(format: "%.0f ms", ms)
    }
}

private extension ConversationSpeedPopover {
    @ViewBuilder
    var averageSpeedBlock: some View {
        if let averageTPS = ConversationSpeedSample.averageTokensPerSecond(from: speedHistory) {
            HStack(spacing: 10) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(LumiPluginLocalization.string("Average speed", bundle: .module))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", averageTPS))
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                        Text(LumiPluginLocalization.string("tokens / second", bundle: .module))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.orange.opacity(0.18), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    var speedHistorySection: some View {
        if !speedHistory.isEmpty {
            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(LumiPluginLocalization.string("Conversation speed trend", bundle: .module))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(String(format: LumiPluginLocalization.string("%d messages", bundle: .module), speedHistory.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ConversationSpeedLineChart(samples: speedHistory)
                    .frame(height: 118)

                HStack {
                    Text(String(format: LumiPluginLocalization.string("Min %.1f", bundle: .module), speedHistory.map(\.tokensPerSecond).min() ?? 0))
                    Spacer()
                    Text(String(format: LumiPluginLocalization.string("Max %.1f", bundle: .module), speedHistory.map(\.tokensPerSecond).max() ?? 0))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ConversationSpeedLineChart: View {
    let samples: [ConversationSpeedSample]
    @State private var hoveredIndex: Int?

    var body: some View {
        Canvas { context, size in
            guard !samples.isEmpty, size.width > 0, size.height > 0 else { return }

            let values = samples.map(\.tokensPerSecond)
            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 0
            let range = max(maxValue - minValue, 1)
            let inset = EdgeInsets(top: 10, leading: 10, bottom: 16, trailing: 10)
            let plotWidth = max(size.width - inset.leading - inset.trailing, 1)
            let plotHeight = max(size.height - inset.top - inset.bottom, 1)

            let points = samples.enumerated().map { offset, sample in
                let xRatio = samples.count == 1 ? 0.5 : Double(offset) / Double(samples.count - 1)
                let yRatio = (sample.tokensPerSecond - minValue) / range
                return CGPoint(
                    x: inset.leading + plotWidth * xRatio,
                    y: inset.top + plotHeight * (1 - yRatio)
                )
            }

            var grid = Path()
            for step in 0...2 {
                let y = inset.top + plotHeight * Double(step) / 2
                grid.move(to: CGPoint(x: inset.leading, y: y))
                grid.addLine(to: CGPoint(x: inset.leading + plotWidth, y: y))
            }
            context.stroke(grid, with: .color(.secondary.opacity(0.16)), lineWidth: 1)

            var fill = smoothedPath(points: points)
            fill.addLine(to: CGPoint(x: points.last?.x ?? inset.leading, y: inset.top + plotHeight))
            fill.addLine(to: CGPoint(x: points.first?.x ?? inset.leading, y: inset.top + plotHeight))
            fill.closeSubpath()
            context.fill(fill, with: .linearGradient(
                Gradient(colors: [.orange.opacity(0.22), .orange.opacity(0.02)]),
                startPoint: CGPoint(x: size.width / 2, y: inset.top),
                endPoint: CGPoint(x: size.width / 2, y: inset.top + plotHeight)
            ))

            context.stroke(smoothedPath(points: points), with: .color(.orange), lineWidth: 2.4)

            if let last = points.last {
                context.fill(Path(ellipseIn: CGRect(x: last.x - 3.5, y: last.y - 3.5, width: 7, height: 7)), with: .color(.orange))
                context.stroke(Path(ellipseIn: CGRect(x: last.x - 5.5, y: last.y - 5.5, width: 11, height: 11)), with: .color(.orange.opacity(0.32)), lineWidth: 2)
            }

            if let hoveredIndex,
               points.indices.contains(hoveredIndex) {
                let point = points[hoveredIndex]
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: point.x, y: inset.top))
                        path.addLine(to: CGPoint(x: point.x, y: inset.top + plotHeight))
                    },
                    with: .color(.orange.opacity(0.45)),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
            }
        }
        .overlay {
            GeometryReader { proxy in
                let inset = EdgeInsets(top: 10, leading: 10, bottom: 16, trailing: 10)
                let plotWidth = max(proxy.size.width - inset.leading - inset.trailing, 1)
                let values = samples.map(\.tokensPerSecond)
                let minValue = values.min() ?? 0
                let maxValue = values.max() ?? 0
                let range = max(maxValue - minValue, 1)
                let plotHeight = max(proxy.size.height - inset.top - inset.bottom, 1)

                ZStack {
                    if let hoveredIndex,
                       samples.indices.contains(hoveredIndex) {
                        let sample = samples[hoveredIndex]
                        let xRatio = samples.count == 1 ? 0.5 : Double(hoveredIndex) / Double(samples.count - 1)
                        let x = inset.leading + plotWidth * xRatio
                        let yRatio = (sample.tokensPerSecond - minValue) / range
                        let y = inset.top + plotHeight * (1 - yRatio)

                        Circle()
                            .fill(.orange)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                            .position(x: x, y: y)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(Self.tooltipDateFormatter.string(from: sample.createdAt))
                                .font(.system(size: 10, weight: .medium))
                            Text("X: \(Self.tooltipDateFormatter.string(from: sample.createdAt))")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text(String(format: "Y: %.1f tokens/s", sample.tokensPerSecond))
                                .font(.system(size: 11, weight: .semibold))
                                .monospacedDigit()
                        }
                        .padding(8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(.secondary.opacity(0.25), lineWidth: 0.5)
                        }
                        .shadow(radius: 3, y: 1)
                        .fixedSize()
                        .position(x: min(max(x, 82), max(proxy.size.width - 82, 82)), y: 34)
                    }
                }
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case let .active(location):
                        guard !samples.isEmpty else { return }
                        let ratio = (location.x - inset.leading) / plotWidth
                        let rawIndex = Int((ratio * CGFloat(samples.count - 1)).rounded())
                        hoveredIndex = min(max(rawIndex, 0), samples.count - 1)
                    case .ended:
                        hoveredIndex = nil
                    }
                }
            }
        }
        .background(Color.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.orange.opacity(0.18), lineWidth: 1)
        )
    }

    private static let tooltipDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private func smoothedPath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)

        guard points.count > 1 else {
            path.addLine(to: first)
            return path
        }

        for index in 0..<(points.count - 1) {
            let current = points[index]
            let next = points[index + 1]
            let previous = index > 0 ? points[index - 1] : current
            let afterNext = index + 2 < points.count ? points[index + 2] : next
            let control1 = CGPoint(
                x: current.x + (next.x - previous.x) / 6,
                y: current.y + (next.y - previous.y) / 6
            )
            let control2 = CGPoint(
                x: next.x - (afterNext.x - current.x) / 6,
                y: next.y - (afterNext.y - current.y) / 6
            )
            path.addCurve(to: next, control1: control1, control2: control2)
        }

        return path
    }
}

enum ToolbarMetrics {
    static let chipIconSize: CGFloat = 10
    static let chipTextSize: CGFloat = 10
    static let chipTextWeight: Font.Weight = .medium
    static let chipSpacing: CGFloat = 3
    static let chipHorizontalPadding: CGFloat = 6
    static let chipVerticalPadding: CGFloat = 3
    static let chipCornerRadius: CGFloat = 5
}
