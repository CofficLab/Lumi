import SwiftUI
import MagicKit

/// Commit 输入视图
///
/// 提供手动输入 commit message 或 AI 自动生成的功能。
/// 集成在 GitCommitDetailView 的底部，当处于工作状态时显示。
struct GitCommitInputView: View {
    @EnvironmentObject var projectVM: ProjectVM

    /// 是否正在生成 AI commit message
    @State private var isGenerating = false

    /// 是否正在提交
    @State private var isCommitting = false

    /// Commit message 文本
    @State var commitMessage: String = ""

    /// 操作结果提示
    @State private var resultMessage: String?
    @State private var resultType: ResultType = .success

    /// 提交成功后的回调
    var onCommitSuccess: (() -> Void)?

    enum ResultType {
        case success
        case error
    }

    var body: some View {
        VStack(spacing: 8) {
            // 输入区域
            HStack(alignment: .top, spacing: 8) {
                // Commit message 输入框
                commitTextField

                // 按钮组
                VStack(spacing: 4) {
                    // AI 生成按钮
                    aiGenerateButton

                    // 提交按钮
                    commitButton
                }
                .frame(width: 100)
            }

            // 结果提示
            if let message = resultMessage {
                resultMessageView(message)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Subviews

    private var commitTextField: some View {
        ZStack(alignment: .topLeading) {
            // 占位文本
            if commitMessage.isEmpty {
                Text(String(localized: "Enter commit message...", table: "GitCommitHistory"))
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "98989E"))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $commitMessage)
                .font(.system(size: 12))
                .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
                .frame(minHeight: 36, maxHeight: 80)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
                .opacity(commitMessage.isEmpty ? 0.9 : 1.0)
        }
        .frame(maxWidth: .infinity)
    }

    private var aiGenerateButton: some View {
        Button(action: {
            Task { await generateAICommitMessage() }
        }) {
            HStack(spacing: 4) {
                if isGenerating {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                }
                Text(String(localized: "AI", table: "GitCommitHistory"))
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(Color(hex: "7C6FFF"))
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "7C6FFF").opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .disabled(isGenerating || isCommitting)
        .help(String(localized: "AI generates commit message", table: "GitCommitHistory"))
    }

    private var commitButton: some View {
        Button(action: {
            Task { await performCommit() }
        }) {
            HStack(spacing: 4) {
                if isCommitting {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                }
                Text(String(localized: "Commit", table: "GitCommitHistory"))
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(.white)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        canCommit
                            ? Color(hex: "7C6FFF")
                            : Color(hex: "7C6FFF").opacity(0.3)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!canCommit || isCommitting || isGenerating)
        .help(String(localized: "Commit changes", table: "GitCommitHistory"))
    }

    private func resultMessageView(_ message: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: resultType == .success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(resultType == .success ? Color(hex: "30D158") : Color(hex: "FF9F0A"))

            Text(message)
                .font(.system(size: 11))
                .foregroundColor(resultType == .success ? Color(hex: "30D158") : Color(hex: "FF9F0A"))
                .lineLimit(2)

            Spacer()
        }
    }

    // MARK: - Computed

    /// 是否可以提交
    private var canCommit: Bool {
        !commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    /// AI 生成 commit message
    private func generateAICommitMessage() async {
        let path = projectVM.currentProjectPath
        guard !path.isEmpty else { return }

        isGenerating = true
        resultMessage = nil

        do {
            // 1. 收集变更
            let changes = try await GitCommitService.gatherChanges(at: path)

            // 2. 生成 commit message
            let config = RootViewContainer.shared.agentSessionConfig.getCurrentConfig()
            let message = try await GitCommitService.generateCommitMessage(
                changes: changes,
                language: .english,
                llmService: RootViewContainer.shared.llmService,
                config: config
            )

            await MainActor.run {
                commitMessage = message
                isGenerating = false
            }
        } catch {
            await MainActor.run {
                isGenerating = false
                resultType = .error

                if let ce = error as? GitCommitError {
                    switch ce {
                    case .noChanges:
                        resultMessage = String(localized: "No changes to commit", table: "GitCommitHistory")
                    case .emptyResponse:
                        resultMessage = String(localized: "AI returned empty response", table: "GitCommitHistory")
                    default:
                        resultMessage = error.localizedDescription
                    }
                } else if error is LLMServiceError {
                    resultMessage = String(localized: "AI request failed, please check API key", table: "GitCommitHistory")
                } else {
                    resultMessage = error.localizedDescription
                }
            }
        }
    }

    /// 执行 commit
    private func performCommit() async {
        let path = projectVM.currentProjectPath
        guard !path.isEmpty, canCommit else { return }

        let message = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        isCommitting = true
        resultMessage = nil

        do {
            let hash = try await GitCommitService.executeCommit(message: message, at: path)

            await MainActor.run {
                isCommitting = false
                resultType = .success
                resultMessage = String(localized: "Committed: \(hash)", table: "GitCommitHistory")
                commitMessage = ""

                // 通知父视图刷新
                onCommitSuccess?()
            }
        } catch {
            await MainActor.run {
                isCommitting = false
                resultType = .error
                resultMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Preview

#Preview {
    GitCommitInputView()
        .inRootView()
        .frame(width: 600)
}
