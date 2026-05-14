import SwiftUI
import MagicKit
import LumiUI

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

    enum Style {
        case panel
        case compact
    }

    var style: Style = .panel

    enum ResultType {
        case success
        case error
    }

    init(style: Style = .panel, onCommitSuccess: (() -> Void)? = nil) {
        self.style = style
        self.onCommitSuccess = onCommitSuccess
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
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(backgroundView)
    }

    // MARK: - Subviews

    private var commitTextField: some View {
        ZStack(alignment: .topLeading) {
            // 占位文本
            if commitMessage.isEmpty {
                Text(String(localized: "Enter commit message...", table: "GitPlugin"))
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
                .frame(minHeight: textEditorMinHeight, maxHeight: textEditorMaxHeight)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
                .opacity(commitMessage.isEmpty ? 0.9 : 1.0)
        }
        .frame(maxWidth: .infinity)
    }

    private var aiGenerateButton: some View {
        Group {
            if isGenerating {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color(hex: "7C6FFF").opacity(0.08))
                    )
            } else {
                AppButton("AI", systemImage: "sparkles", style: .ghost, size: .small, fillsWidth: true) {
                    Task { await generateAICommitMessage() }
                }
                .disabled(isGenerating || isCommitting)
                .help(String(localized: "AI generates commit message", table: "GitPlugin"))
            }
        }
    }

    private var commitButton: some View {
        Group {
            if isCommitting {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color(hex: "7C6FFF"))
                    )
                    .foregroundColor(.white)
            } else {
                AppButton("Commit", systemImage: "checkmark.circle.fill", style: .primary, size: .small, fillsWidth: true) {
                    Task { await performCommit() }
                }
                .disabled(!canCommit || isGenerating)
                .help(String(localized: "Commit changes", table: "GitPlugin"))
            }
        }
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

    private var horizontalPadding: CGFloat {
        style == .panel ? 16 : 12
    }

    private var verticalPadding: CGFloat {
        style == .panel ? 8 : 8
    }

    private var textEditorMinHeight: CGFloat {
        style == .panel ? 36 : 42
    }

    private var textEditorMaxHeight: CGFloat {
        style == .panel ? 80 : 76
    }

    @ViewBuilder
    private var backgroundView: some View {
        if style == .panel {
            Color(NSColor.controlBackgroundColor).opacity(0.5)
        } else {
            Color.clear
        }
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
            let config = RootContainer.shared.agentSessionConfig.getCurrentConfig()
            let message = try await GitCommitService.generateCommitMessage(
                changes: changes,
                language: .english,
                llmService: RootContainer.shared.llmService,
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
                        resultMessage = String(localized: "No changes to commit", table: "GitPlugin")
                    case .emptyResponse:
                        resultMessage = String(localized: "AI returned empty response", table: "GitPlugin")
                    default:
                        resultMessage = error.localizedDescription
                    }
                } else if error is LLMServiceError {
                    resultMessage = String(localized: "AI request failed, please check API key", table: "GitPlugin")
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
                resultMessage = String(localized: "Committed: \(hash)", table: "GitPlugin")
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
