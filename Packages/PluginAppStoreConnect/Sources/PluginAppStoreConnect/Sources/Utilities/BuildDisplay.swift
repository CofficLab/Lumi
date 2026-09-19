import SwiftUI

/// Build 在选择控件与选项列表中的展示规则。
///
/// 「已分配」状态不再用文字后缀表达，而是通过版本号左侧图标高亮体现。
enum BuildDisplay {
    /// 选项文案：营销版本号 + 构建号，必要时追加处理状态后缀
    static func label(for build: ConnectBuild) -> String {
        var label = build.displayLabel
        if build.isProcessing {
            label += AppStoreConnectLocalization.string(" (processing…)")
        } else if !build.isAssignable {
            label += AppStoreConnectLocalization.string(" (invalid)")
        }
        return label
    }

    /// 版本号左侧图标
    static func icon(for build: ConnectBuild) -> String {
        build.isAssignable ? "shippingbox" : "exclamationmark.triangle"
    }

    /// 图标颜色：已分配的构建用强调色高亮，其余按可分配状态区分
    static func iconColor(for build: ConnectBuild, isAssigned: Bool) -> Color {
        if isAssigned {
            return .accentColor
        }
        return build.isAssignable ? .secondary : .orange
    }
}
