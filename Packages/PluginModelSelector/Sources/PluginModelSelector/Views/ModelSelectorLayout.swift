import Foundation
import SwiftUI

/// 模型选择弹窗左右两栏共享的布局常量。
///
/// 弹窗是「左供应商栏 + 右模型栏」的双栏结构，两栏顶部各有一行筛选控件
/// （左侧：常用/云端/本地 分段控件；右侧：模型能力标签），其下各有一条分割线。
/// 只要两行控件高度不一致，左右分割线就会错位成两条线。
/// 两侧统一引用这里的常量，从源头消除错位。
enum ModelSelectorLayout {
    /// 顶部筛选行的内容高度（不含垂直内边距）。
    ///
    /// 取 24pt：与 macOS 分段控件的标准高度一致，右侧标签行按此高度垂直居中。
    static let filterRowContentHeight: CGFloat = 24

    /// 顶部筛选行的垂直内边距（左右两栏必须一致）。
    static let filterRowVerticalPadding: CGFloat = 6

    /// 搜索行的内容高度（不含垂直内边距）。
    ///
    /// 与 `AppSearchBar` 的实际高度一致；右侧只有刷新按钮时按钮也按此高度占位，
    /// 保证两栏的搜索行分割线对齐。
    static let searchRowContentHeight: CGFloat = 32

    /// 搜索行的垂直内边距（左右两栏必须一致）。
    static let searchRowVerticalPadding: CGFloat = 6
}
