import LumiUI
import SwiftUI

/// 项目存储位置图标。
///
/// 本机磁盘用普通文件夹；外置设备（U 盘、移动硬盘）用硬盘图标；
/// 网络卷用网络图标；项目目录已从磁盘上消失用问号文件夹；卷不可达
/// （设备已拔出）用警告三角。
///
/// 项目不可用时改用警告色，让用户一眼看出这个条目出了问题。
struct ProjectStorageIcon: View {
    let kind: ProjectStorageKind
    var size: CGFloat = 12
    var weight: Font.Weight = .semibold
    /// 图标颜色。`nil` 表示沿用父级的前景色。
    var tint: Color?

    @LumiTheme private var theme

    var body: some View {
        Group {
            if let color = foregroundColor {
                image.foregroundStyle(color)
            } else {
                image
            }
        }
    }

    private var image: some View {
        Image(systemName: kind.symbolName)
            .font(.system(size: size, weight: weight))
    }

    /// 不可用状态优先用警告色；否则用调用方指定的颜色。
    private var foregroundColor: Color? {
        if kind.isUnavailable {
            return theme.warning
        }
        return tint
    }
}
