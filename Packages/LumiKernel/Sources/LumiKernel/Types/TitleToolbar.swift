import Foundation
import SwiftUI

// MARK: - Title Toolbar Placement

/// 标题栏工具栏位置
public enum TitleToolbarPlacement: Sendable {
    /// 左侧
    case leading
    /// 中间
    case center
    /// 右侧
    case trailing
}

// MARK: - Title Toolbar Item

/// 标题栏工具栏项 - 旧版 (LumiTitleToolbarItem 形式) 的 typealias
public typealias TitleToolbarItem = LumiTitleToolbarItem
