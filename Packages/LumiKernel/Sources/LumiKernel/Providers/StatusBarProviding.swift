import Foundation
import SwiftUI

// MARK: - Status Bar Capability Protocol

/// 状态栏能力协议
///
/// 定义 LumiCore 需要的状态栏管理功能，由具体布局插件实现。
/// 负责管理状态栏项的注册和查询。
@MainActor
public protocol StatusBarProviding: ObservableObject {
    /// 所有已注册的状态栏项（按注册顺序）
    var allStatusBarItems: [StatusBarItem] { get }

    /// 按位置获取状态栏项
    func statusBarItems(placement: StatusBarPlacement) -> [StatusBarItem]

    /// 注册状态栏项
    func registerStatusBarItem(_ item: StatusBarItem)

    /// 注销状态栏项
    func unregisterStatusBarItem(id: String)
}
