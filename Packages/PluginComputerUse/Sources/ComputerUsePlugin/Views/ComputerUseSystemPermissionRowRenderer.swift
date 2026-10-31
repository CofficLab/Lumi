import Foundation
import KitAgentTool
import ProviderMessageRendering
import SwiftUI

/// Computer Use 系统权限提示卡的无障碍标识符。
///
/// UI 测试必须按标识符定位按钮：按钮文案是随 `-AppleLanguages` 变化的
/// 本地化文本，按文案定位在非英文环境下必然失败。
enum ComputerUseSystemPermissionAccessibility {
    static let card = "lumi.computer-use-system-permission.card"
    static let title = "lumi.computer-use-system-permission.title"
    /// 「打开系统设置」按钮：按缺失的权限区分。
    static func button(_ permission: ComputerUseSystemPermission) -> String {
        "lumi.computer-use-system-permission.\(permission.rawValue)"
    }
    /// 「打开 Lumi 设置」按钮。
    static let lumiSettings = "lumi.computer-use-system-permission.lumi-settings"
}

/// Computer Use 系统权限提示卡的行渲染器。
///
/// 只在工具**因缺少 macOS 系统权限而失败**时渲染：此时结果内容里带着
/// `ComputerUseSystemPermissionCoordinator` 的载荷。
///
/// - Note: priority 必须高于通用工具授权卡片（`ToolApprovalRowRenderer`
///   的 120）。系统权限提示与授权卡片都是「等待用户处理」的行，
///   但语义完全不同：授权卡片可点「允许」，系统权限卡只能跳转设置。
///   两者都用 `pendingAuthorization` 判定，因此优先级必须显式区分。
struct ComputerUseSystemPermissionRowRenderer: ToolCallRowRenderer {
    static let id = "computer-use-system-permission-row"
    static let priority = 200

    public func canRender(toolCall: ToolCall) -> Bool {
        guard let content = toolCall.result?.content else { return false }
        // 只有载荷确实是系统权限提示时才接管，避免误抢其他失败结果。
        return ComputerUseSystemPermissionCoordinator.request(from: content) != nil
    }

    @MainActor
    public func render(toolCall: ToolCall, message: ToolCallRowMessageContext) -> AnyView {
        guard let content = toolCall.result?.content,
              let request = ComputerUseSystemPermissionCoordinator.request(from: content) else {
            return AnyView(Text(""))
        }
        return AnyView(
            ComputerUseSystemPermissionCard(request: request)
        )
    }
}
