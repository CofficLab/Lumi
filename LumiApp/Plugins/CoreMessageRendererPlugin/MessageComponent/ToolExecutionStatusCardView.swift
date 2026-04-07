import Foundation
import MagicKit
import SwiftUI

struct ToolExecutionStatusCardView: View {
    let snapshot: ToolExecutionStatusSnapshot
    let conversationId: UUID
    @EnvironmentObject private var taskCancellationVM: TaskCancellationVM
    @State private var isExpanded: Bool
    @State private var didRequestStop = false

    init(snapshot: ToolExecutionStatusSnapshot, conversationId: UUID) {
        self.snapshot = snapshot
        self.conversationId = conversationId
        _isExpanded = State(initialValue: snapshot.phase == .running)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MessageHeaderView {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                    Text("工具执行")
                        .font(AppUI.Typography.caption1)
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                    Text(snapshot.summary)
                        .font(AppUI.Typography.caption2)
                        .foregroundColor(AppUI.Color.semantic.textSecondary.opacity(0.8))
                        .lineLimit(1)
                }
            } trailing: {
                HStack(spacing: 8) {
                    if snapshot.phase == .running {
                        Button {
                            didRequestStop = true
                            taskCancellationVM.requestCancel(conversationId: conversationId)
                        } label: {
                            Text(didRequestStop ? "停止中…" : "停止本轮")
                                .font(AppUI.Typography.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.red.opacity(0.9))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    AppTag(snapshot.phase.label)
                    if let elapsedSeconds = snapshot.elapsedSeconds {
                        Text("\(elapsedSeconds)s")
                            .font(AppUI.Typography.caption2)
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
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
                                .font(AppUI.Typography.caption1)
                                .foregroundColor(AppUI.Color.semantic.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            if let current = snapshot.current, let total = snapshot.total {
                                Text("\(current)/\(total)")
                                    .font(AppUI.Typography.caption2)
                                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                            }
                        }

                        if let lines = snapshot.shellLines, let bytes = snapshot.shellBytes {
                            Text("输出：\(lines) 行，\(Self.byteFormatter.string(fromByteCount: Int64(bytes)))")
                                .font(AppUI.Typography.caption2)
                                .foregroundColor(AppUI.Color.semantic.textSecondary)
                        }

                        if let latestOutput = snapshot.latestOutput, !latestOutput.isEmpty {
                            Text(latestOutput)
                                .font(AppUI.Typography.code)
                                .foregroundColor(AppUI.Color.semantic.textPrimary)
                                .lineLimit(3)
                        }

                        if let errorSummary = snapshot.errorSummary {
                            Text(errorSummary)
                                .font(AppUI.Typography.caption2)
                                .foregroundColor(AppUI.Color.semantic.error)
                                .lineLimit(2)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB]
        formatter.countStyle = .file
        return formatter
    }()
}

struct ToolExecutionStatusSnapshot {
    enum Phase {
        case running
        case completed
        case failed
        case cancelled

        var label: String {
            switch self {
            case .running: return "进行中"
            case .completed: return "已完成"
            case .failed: return "失败"
            case .cancelled: return "已停止"
            }
        }
    }

    let phase: Phase
    let toolName: String
    let current: Int?
    let total: Int?
    let elapsedSeconds: Int?
    let shellLines: Int?
    let shellBytes: Int?
    let latestOutput: String?
    let errorSummary: String?

    var progressRatio: Double? {
        guard let current, let total, total > 0 else { return nil }
        return max(0, min(1, Double(current) / Double(total)))
    }

    var summary: String {
        if let current, let total {
            return "\(toolName) · \(current)/\(total)"
        }
        return toolName
    }

    static func parse(from content: String) -> ToolExecutionStatusSnapshot? {
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
            toolName: "工具",
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
    let groups: [String?]

    func groupValue(_ index: Int) -> String {
        groups[index] ?? ""
    }

    func groupOptional(_ index: Int) -> String? {
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
