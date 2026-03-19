import SwiftUI
import Foundation

struct UserFacingError: Equatable {
    enum Category: String {
        case network
        case auth
        case permission
        case rateLimit
        case service
        case unknown
    }

    let category: Category
    let title: String
    let message: String
    let recoverySuggestions: [String]
}

/// 错误状态 ViewModel
/// 专门管理错误消息状态，避免因 AgentVM 其他状态变化导致不必要的视图重新渲染
@MainActor
final class ErrorStateVM: ObservableObject {
    /// 错误消息
    @Published public fileprivate(set) var errorMessage: String?
    @Published public fileprivate(set) var userFacingError: UserFacingError?

    /// 设置错误消息
    func setErrorMessage(_ message: String?) {
        let normalized = message?.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = normalized
        userFacingError = normalized.map(Self.classifyErrorMessage)
    }

    func clear() {
        errorMessage = nil
        userFacingError = nil
    }

    private static func classifyErrorMessage(_ rawMessage: String) -> UserFacingError {
        let lowered = rawMessage.lowercased()

        if rawMessage.contains("超时") || lowered.contains("timed out") {
            return UserFacingError(
                category: .network,
                title: "请求超时",
                message: rawMessage,
                recoverySuggestions: [
                    "检查网络连接是否稳定",
                    "稍后重试，避免在网络波动时连续发送",
                    "如持续超时，可切换模型后再试"
                ]
            )
        }

        if rawMessage.contains("网络") || lowered.contains("not connected") || lowered.contains("network") {
            return UserFacingError(
                category: .network,
                title: "网络连接异常",
                message: rawMessage,
                recoverySuggestions: [
                    "确认当前设备可访问互联网",
                    "切换网络后重新发送",
                    "如使用代理，请检查代理配置"
                ]
            )
        }

        if rawMessage.contains("权限") || lowered.contains("permission") || lowered.contains("denied") {
            return UserFacingError(
                category: .permission,
                title: "权限不足",
                message: rawMessage,
                recoverySuggestions: [
                    "在系统设置中授予必要权限",
                    "确认当前操作目录可读写",
                    "授权后重新尝试当前操作"
                ]
            )
        }

        if lowered.contains("api key") || lowered.contains("401") || lowered.contains("unauthorized") {
            return UserFacingError(
                category: .auth,
                title: "鉴权失败",
                message: rawMessage,
                recoverySuggestions: [
                    "检查 API Key 是否填写正确",
                    "确认所选供应商与模型配置一致",
                    "更新配置后重新发送消息"
                ]
            )
        }

        if lowered.contains("429") || lowered.contains("rate limit") || rawMessage.contains("频率限制") {
            return UserFacingError(
                category: .rateLimit,
                title: "请求过于频繁",
                message: rawMessage,
                recoverySuggestions: [
                    "等待 10-30 秒后重试",
                    "降低并发请求数量",
                    "必要时切换到其他可用模型"
                ]
            )
        }

        if lowered.contains("http error") || lowered.contains("服务") || lowered.contains("server") {
            return UserFacingError(
                category: .service,
                title: "服务暂时不可用",
                message: rawMessage,
                recoverySuggestions: [
                    "稍后重新尝试",
                    "切换其他模型验证是否可用",
                    "若多次失败，请提交反馈并附带错误信息"
                ]
            )
        }

        return UserFacingError(
            category: .unknown,
            title: "操作失败",
            message: rawMessage,
            recoverySuggestions: [
                "检查当前输入与上下文是否完整",
                "重新发送一次请求",
                "若问题持续，请通过“反馈问题”提交日志线索"
            ]
        )
    }
}
