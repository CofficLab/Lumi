import SwiftUI
import LumiCoreKit
import LumiUI

/// Commit 输入视图
///
/// 提供手动输入 commit message 或 AI 自动生成的功能。
/// 集成在 GitCommitDetailView 的底部，当处于工作状态时显示。
public struct GitCommitInputView: View {
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
    public var onCommitSuccess: (() -> Void)?

    public enum Style {
        case panel
        case compact
    }

    public var style: Style = .panel

    private enum ResultType {
        case success
        case error
    }

    public init(style: Style = .panel, onCommitSuccess: (() -> Void)? = nil) {
        self.style = style
        self.onCommitSuccess = onCommitSuccess
    }

    public var body: some View {
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
                Text(LumiPluginLocalization.string("Enter commit message...", bundle: .module))
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
                AppButton(LumiPluginLocalization.string("AI", bundle: .module), systemImage: "sparkles", style: .ghost, size: .small, fillsWidth: true, action: {
                    Task { await generateAICommitMessage() }
                })
                .disabled(isGenerating || isCommitting)
                .help(LumiPluginLocalization.string("AI generates commit message", bundle: .module))
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
                AppButton(LumiPluginLocalization.string("Commit", bundle: .module), systemImage: "checkmark.circle.fill", style: .primary, size: .small, fillsWidth: true, action: {
                    Task { await performCommit() }
                })
                .disabled(!canCommit || isGenerating)
                .help(LumiPluginLocalization.string("Commit changes", bundle: .module))
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
        let path = LumiCore.projectState?.currentProject?.path ?? ""
        guard !path.isEmpty else { return }

        guard let chatService = GitRuntimeBridge.chatServiceProvider?() else {
            await MainActor.run {
                resultType = .error
                resultMessage = LumiPluginLocalization.string("LLM not configured", bundle: .module)
            }
            return
        }

        isGenerating = true
        resultMessage = nil

        do {
            let changes = try await GitCommitService.gatherChanges(at: path)
            let message = try await GitCommitService.generateCommitMessage(
                changes: changes,
                language: .english,
                chatService: chatService
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
                        resultMessage = LumiPluginLocalization.string("No changes to commit", bundle: .module)
                    case .emptyResponse:
                        resultMessage = LumiPluginLocalization.string("AI returned empty response", bundle: .module)
                    default:
                        resultMessage = error.localizedDescription
                    }
                } else {
                    resultMessage = error.localizedDescription
                }
            }
        }
    }

    /// 执行 commit
    private func performCommit() async {
        let path = LumiCore.projectState?.currentProject?.path ?? ""
        guard !path.isEmpty, canCommit else { return }

        let message = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        isCommitting = true
        resultMessage = nil

        do {
            let hash = try await GitCommitService.executeCommit(message: message, at: path)

            await MainActor.run {
                isCommitting = false
                resultType = .success
                resultMessage = LumiPluginLocalization.string("Committed: \(hash)", bundle: .module)
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
