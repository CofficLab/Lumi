import SwiftUI

/// 项目存储位置图标。
///
/// 本机磁盘用普通文件夹；外置设备（U 盘、移动硬盘）用硬盘图标；
/// 网络卷用网络图标；路径不可达（设备已拔出）用问号文件夹。
struct ProjectStorageIcon: View {
    let kind: ProjectStorageKind
    var size: CGFloat = 12
    var weight: Font.Weight = .semibold

    var body: some View {
        Image(systemName: kind.symbolName)
            .font(.system(size: size, weight: weight))
    }
}
