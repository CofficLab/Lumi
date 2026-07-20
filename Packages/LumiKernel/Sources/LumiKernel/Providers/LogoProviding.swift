import Foundation
import LumiCoreLayout
import SwiftUI

// MARK: - Logo Capability Protocol

/// Logo 能力协议
///
/// 定义 LumiCore 需要的 Logo 管理功能，由具体布局插件实现。
/// 负责管理 Logo 项的注册和查询。
@MainActor
public protocol LogoProviding: ObservableObject {
    /// 所有已注册的 Logo 项
    var allLogoItems: [LogoItem] { get }

    /// 注册 Logo 项
    func registerLogoItem(_ item: LogoItem)

    /// 注销 Logo 项
    func unregisterLogoItem(id: String)
}
