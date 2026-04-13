import MagicKit
import SwiftUI

// MARK: - Error Message
//
/// 负责渲染错误类消息（如 API 调用失败、网络错误等），统一样式
struct ErrorMessage: View {
    let message: ChatMessage
    @Binding var showRawMessage: Bool

    @EnvironmentObject private var projectVM: ProjectVM

    private var zh: Bool {
        projectVM.languagePreference == .chinese
    }

    private var titleText: String {
        zh ? "错误" : "Error"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header

            VStack(alignment: .leading, spacing: 8) {
                errorContent
            }
            .messageBubbleStyle(role: message.role, isError: true)
        }
    }

    // MARK: - Error Content

    @ViewBuilder
    private var errorContent: some View {
        if message.content == ChatMessage.apiKeyMissingSystemContentKey {
            ApiKeyMissingErrorView(message: message)
        } else if message.content == ChatMessage.apiRequestFailedErrorKey {
            SpecialErrorView(
                title: errorTitle(for: ChatMessage.apiRequestFailedErrorKey),
                description: errorDescription(for: ChatMessage.apiRequestFailedErrorKey),
                suggestion: errorSuggestion(for: ChatMessage.apiRequestFailedErrorKey)
            )
        } else if message.content == ChatMessage.networkConnectionErrorKey {
            SpecialErrorView(
                title: errorTitle(for: ChatMessage.networkConnectionErrorKey),
                description: errorDescription(for: ChatMessage.networkConnectionErrorKey),
                suggestion: errorSuggestion(for: ChatMessage.networkConnectionErrorKey)
            )
        } else if message.content == ChatMessage.parsingErrorKey {
            SpecialErrorView(
                title: errorTitle(for: ChatMessage.parsingErrorKey),
                description: errorDescription(for: ChatMessage.parsingErrorKey),
                suggestion: errorSuggestion(for: ChatMessage.parsingErrorKey)
            )
        } else if message.content == ChatMessage.authenticationErrorKey {
            SpecialErrorView(
                title: errorTitle(for: ChatMessage.authenticationErrorKey),
                description: errorDescription(for: ChatMessage.authenticationErrorKey),
                suggestion: errorSuggestion(for: ChatMessage.authenticationErrorKey)
            )
        } else if message.content == ChatMessage.quotaExceededErrorKey {
            SpecialErrorView(
                title: errorTitle(for: ChatMessage.quotaExceededErrorKey),
                description: errorDescription(for: ChatMessage.quotaExceededErrorKey),
                suggestion: errorSuggestion(for: ChatMessage.quotaExceededErrorKey)
            )
        } else if message.content == ChatMessage.modelNotAvailableErrorKey {
            SpecialErrorView(
                title: errorTitle(for: ChatMessage.modelNotAvailableErrorKey),
                description: errorDescription(for: ChatMessage.modelNotAvailableErrorKey),
                suggestion: errorSuggestion(for: ChatMessage.modelNotAvailableErrorKey)
            )
        } else if message.content == ChatMessage.loadingLocalModelFailedSystemContentKey {
            SpecialErrorView(
                title: errorTitle(for: ChatMessage.loadingLocalModelFailedSystemContentKey),
                description: errorDescription(for: ChatMessage.loadingLocalModelFailedSystemContentKey),
                suggestion: errorSuggestion(for: ChatMessage.loadingLocalModelFailedSystemContentKey)
            )
        } else if message.content == ChatMessage.llmModelEmptyContentKey ||
                  message.content == ChatMessage.llmProviderIdEmptyContentKey ||
                  message.content == ChatMessage.llmTemperatureInvalidContentKey ||
                  message.content == ChatMessage.llmMaxTokensInvalidContentKey ||
                  message.content == ChatMessage.llmProviderNotFoundContentKey ||
                  message.content.hasPrefix(ChatMessage.llmInvalidBaseURLContentKey) {
            LLMInlineConfigErrorView(message: message)
        } else {
            DefaultErrorView(
                title: titleText,
                message: message.content
            )
        }
    }

    // MARK: - Error Details Helpers

    private func errorTitle(for contentKey: String) -> String {
        switch contentKey {
        case ChatMessage.apiRequestFailedErrorKey:
            return zh ? "API 请求失败" : "API Request Failed"
        case ChatMessage.networkConnectionErrorKey:
            return zh ? "网络连接失败" : "Network Connection Failed"
        case ChatMessage.parsingErrorKey:
            return zh ? "解析错误" : "Parsing Error"
        case ChatMessage.authenticationErrorKey:
            return zh ? "认证失败" : "Authentication Failed"
        case ChatMessage.quotaExceededErrorKey:
            return zh ? "配额已超限" : "Quota Exceeded"
        case ChatMessage.modelNotAvailableErrorKey:
            return zh ? "模型不可用" : "Model Not Available"
        case ChatMessage.loadingLocalModelFailedSystemContentKey:
            return zh ? "本地模型加载失败" : "Local Model Load Failed"
        default:
            return titleText
        }
    }

    private func errorDescription(for contentKey: String) -> String {
        switch contentKey {
        case ChatMessage.apiRequestFailedErrorKey:
            return zh ? "无法完成 API 请求，请检查网络连接或稍后重试。" : "Unable to complete the API request. Please check your network connection or try again later."
        case ChatMessage.networkConnectionErrorKey:
            return zh ? "无法连接到服务器，请检查网络设置。" : "Cannot connect to the server. Please check your network settings."
        case ChatMessage.parsingErrorKey:
            return zh ? "无法解析服务器响应，可能是数据格式不正确。" : "Unable to parse the server response. The data format might be incorrect."
        case ChatMessage.authenticationErrorKey:
            return zh ? "API Key 无效或已过期，请检查配置。" : "Invalid or expired API Key. Please check your configuration."
        case ChatMessage.quotaExceededErrorKey:
            return zh ? "已达到使用配额上限，请检查账户状态。" : "Usage quota has been reached. Please check your account status."
        case ChatMessage.modelNotAvailableErrorKey:
            return zh ? "所选模型当前不可用，请尝试其他模型。" : "The selected model is currently unavailable. Please try a different model."
        case ChatMessage.loadingLocalModelFailedSystemContentKey:
            return zh ? "无法加载本地模型，请检查模型文件或尝试其他模型。" : "Unable to load the local model. Please check your model files or try a different model."
        default:
            return ""
        }
    }

    private func errorSuggestion(for contentKey: String) -> String? {
        switch contentKey {
        case ChatMessage.apiRequestFailedErrorKey:
            return zh ? "建议：检查网络连接，或稍后重试" : "Suggestion: Check your network connection or try again later"
        case ChatMessage.networkConnectionErrorKey:
            return zh ? "建议：确认网络设置正确，或切换网络环境" : "Suggestion: Verify network settings or switch to a different network"
        case ChatMessage.parsingErrorKey:
            return zh ? "建议：联系支持团队并提供错误详情" : "Suggestion: Contact support with error details"
        case ChatMessage.authenticationErrorKey:
            return zh ? "建议：更新 API Key 配置" : "Suggestion: Update your API Key configuration"
        case ChatMessage.quotaExceededErrorKey:
            return zh ? "建议：升级计划或等待配额重置" : "Suggestion: Upgrade your plan or wait for quota reset"
        case ChatMessage.modelNotAvailableErrorKey:
            return zh ? "建议：选择其他可用模型" : "Suggestion: Select a different available model"
        case ChatMessage.loadingLocalModelFailedSystemContentKey:
            return zh ? "建议：检查模型文件完整性或重新下载模型" : "Suggestion: Verify model file integrity or re-download the model"
        default:
            return nil
        }
    }

    // MARK: - Header

    private var header: some View {
        MessageHeaderView {
            HStack(alignment: .center, spacing: 6) {
                AvatarView.error
                AppIdentityRow(title: titleText)
            }
        } trailing: {
            HStack(alignment: .center, spacing: 12) {
                CopyMessageButton(
                    content: message.content,
                    showFeedback: .constant(false)
                )

                Text(formatTimestamp(message.timestamp))
                    .font(AppUI.Typography.caption2)
                    .foregroundColor(AppUI.Color.semantic.textSecondary)

                RawMessageToggleButton(showRawMessage: $showRawMessage)
            }
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(for: date) ?? ""
    }
}
