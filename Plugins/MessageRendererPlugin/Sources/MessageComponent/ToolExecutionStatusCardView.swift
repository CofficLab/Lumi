import LumiUI
import Foundation
import SwiftUI

public struct ToolExecutionStatusCardView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let snapshot: ToolExecutionStatusSnapshot
    public let conversationId: UUID
    @LumiMotionPreferenceReader private var motionPreference
    @State private var isExpanded: Bool
    @State private var didRequestStop = false

    public init(snapshot: ToolExecutionStatusSnapshot, conversationId: UUID) {
        self.snapshot = snapshot
        self.conversationId = conversationId
        _isExpanded = State(initialValue: snapshot.phase == .running)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MessageHeaderView {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.appMicroEmphasized)
                        .foregroundColor(theme.textSecondary)
                    Text(String(localized: "工具执行", bundle: .module))
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                    Text(snapshot.summary)
                        .font(.appMicro)
                        .foregroundColor(theme.textSecondary.opacity(0.8))
                        .lineLimit(1)
                }
            } trailing: {
                HStack(spacing: 8) {
                    if snapshot.phase == .running {
                        AppButton(
                            didRequestStop
                                ? String(localized: "Stopping…", bundle: .module)
                                : String(localized: "Stop Current Turn", bundle: .module),
                            style: .destructive,
                            size: .small
                        ) {
                            didRequestStop = true
                            MessageRendererRuntime.cancelTurn(conversationId)
                        }
                    }
                    AppTag(snapshot.phase.label)
                    if let elapsedSeconds = snapshot.elapsedSeconds {
                        Text("\(elapsedSeconds)s")
                            .font(.appMicro)
                            .foregroundColor(theme.textSecondary)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                LumiMotion.animate(LumiMotion.enabled(LumiMotion.disclosure, preference: motionPreference)) {
                    isExpanded.toggle()
                }
            }

            if isExpanded {
                AppCard(
                    style: .subtle,
                    padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let ratio = snapshot.progressRatio {
                            ProgressView(value: ratio)
                                .progressViewStyle(.linear)
                        }

                        HStack(spacing: 10) {
                            Text(snapshot.toolName)
                                .font(.appCaption)
                                .foregroundColor(theme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            if let current = snapshot.current, let total = snapshot.total {
                                Text("\(current)/\(total)")
                                    .font(.appMicro)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }

                        if let lines = snapshot.shellLines, let bytes = snapshot.shellBytes {
                            Text(String(format: String(localized: "Output: %lld lines, %@", bundle: .module), lines, Self.byteFormatter.string(fromByteCount: Int64(bytes))))
                                .font(.appMicro)
                                .foregroundColor(theme.textSecondary)
                        }

                        if let latestOutput = snapshot.latestOutput, !latestOutput.isEmpty {
                            Text(latestOutput)
                                .font(.appMonoCaption)
                                .foregroundColor(theme.textPrimary)
                                .lineLimit(3)
                        }

                        if let errorSummary = snapshot.errorSummary {
                            Text(errorSummary)
                                .font(.appMicro)
                                .foregroundColor(theme.error)
                                .lineLimit(2)
                        }
                    }
                    .padding(12)
                }
                .appDisclosureContentTransition(preference: motionPreference)
            }
        }
        .padding(.vertical, 4)
        .animation(LumiMotion.enabled(LumiMotion.disclosure, preference: motionPreference), value: isExpanded)
    }

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB]
        formatter.countStyle = .file
        return formatter
    }()
}

public struct ToolExecutionStatusSnapshot {
    public enum Phase {
        case running
        case completed
        case failed
        case cancelled

        var label: String {
            switch self {
            case .running: return String(localized: "Running", bundle: .module)
            case .completed: return String(localized: "Completed", bundle: .module)
            case .failed: return String(localized: "Failed", bundle: .module)
            case .cancelled: return String(localized: "Stopped", bundle: .module)
            }
        }
    }

    public let phase: Phase
    public let toolName: String
    public let current: Int?
    public let total: Int?
    public let elapsedSeconds: Int?
    public let shellLines: Int?
    public let shellBytes: Int?
    public let latestOutput: String?
    public let errorSummary: String?

    public var progressRatio: Double? {
        guard let current, let total, total > 0 else { return nil }
        return max(0, min(1, Double(current) / Double(total)))
    }

    public var summary: String {
        if let current, let total {
            return "\(toolName) · \(current)/\(total)"
        }
        return toolName
    }

    public static func parse(from content: String) -> ToolExecutionStatusSnapshot? {
        if let running = parseRunning(content) { return running }
        if let completed = parseCompleted(content) { return completed }
        if let failed = parseFailed(content) { return failed }
        if let cancelled = parseCancelled(content) { return cancelled }
        return nil
    }

    private static func parseRunning(_ content: String) -> ToolExecutionStatusSnapshot? {
        let pattern = #"^正在执行工具 (\d+)\/(\d+)：(.+?)（(\d+)s(?:，(\d+)行，(\d+)B(?:，最近输出：(.*))?)?）$"#
        guard let match = content.wholeMatch(of: pattern) else { return nil }
        return ToolExecutionStatusSnapshot(
            phase: .running,
            toolName: match.groupValue(3),
            current: Int(match.groupValue(1)),
            total: Int(match.groupValue(2)),
            elapsedSeconds: Int(match.groupValue(4)),
            shellLines: match.groupOptional(5).flatMap(Int.init),
            shellBytes: match.groupOptional(6).flatMap(Int.init),
            latestOutput: match.groupOptional(7),
            errorSummary: nil
        )
    }

    private static func parseCompleted(_ content: String) -> ToolExecutionStatusSnapshot? {
        let pattern = #"^工具 (\d+)\/(\d+) 已完成：(.+)$"#
        guard let match = content.wholeMatch(of: pattern) else { return nil }
        return ToolExecutionStatusSnapshot(
            phase: .completed,
            toolName: match.groupValue(3),
            current: Int(match.groupValue(1)),
            total: Int(match.groupValue(2)),
            elapsedSeconds: nil,
            shellLines: nil,
            shellBytes: nil,
            latestOutput: nil,
            errorSummary: nil
        )
    }

    private static func parseFailed(_ content: String) -> ToolExecutionStatusSnapshot? {
        let pattern = #"^工具执行失败 (\d+)\/(\d+)：(.+?)（(.+)）$"#
        guard let match = content.wholeMatch(of: pattern) else { return nil }
        return ToolExecutionStatusSnapshot(
            phase: .failed,
            toolName: match.groupValue(3),
            current: Int(match.groupValue(1)),
            total: Int(match.groupValue(2)),
            elapsedSeconds: nil,
            shellLines: nil,
            shellBytes: nil,
            latestOutput: nil,
            errorSummary: match.groupOptional(4)
        )
    }

    private static func parseCancelled(_ content: String) -> ToolExecutionStatusSnapshot? {
        let withNamePattern = #"^已停止执行工具：(.+)$"#
        if let withName = content.wholeMatch(of: withNamePattern) {
            return ToolExecutionStatusSnapshot(
                phase: .cancelled,
                toolName: withName.groupValue(1),
                current: nil,
                total: nil,
                elapsedSeconds: nil,
                shellLines: nil,
                shellBytes: nil,
                latestOutput: nil,
                errorSummary: nil
            )
        }
        guard content == "已停止执行工具" else { return nil }
        return ToolExecutionStatusSnapshot(
            phase: .cancelled,
            toolName: String(localized: "Tool", bundle: .module),
            current: nil,
            total: nil,
            elapsedSeconds: nil,
            shellLines: nil,
            shellBytes: nil,
            latestOutput: nil,
            errorSummary: nil
        )
    }
}

private struct RegexMatch {
    public let groups: [String?]

    public func groupValue(_ index: Int) -> String {
        groups[index] ?? ""
    }

    public func groupOptional(_ index: Int) -> String? {
        guard index >= 0 && index < groups.count else { return nil }
        return groups[index]
    }
}

private extension String {
    func wholeMatch(of pattern: String) -> RegexMatch? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(startIndex..<endIndex, in: self)
        guard let match = regex.firstMatch(in: self, options: [], range: range), match.range == range else {
            return nil
        }
        var groups: [String?] = []
        for i in 0..<match.numberOfRanges {
            let r = match.range(at: i)
            if r.location == NSNotFound || r.length == 0 {
                groups.append(nil)
            } else if let sr = Range(r, in: self) {
                groups.append(String(self[sr]))
            } else {
                groups.append(nil)
            }
        }
        return RegexMatch(groups: groups)
    }
}
