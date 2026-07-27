import SwiftUI
import LumiUI

/// 状态栏“打开”按钮弹出的内容:实时展示 Idle Time 快照。
///
/// 包一层 `AppIdleTimeVM` 以便 popover 内的数据随推断结果实时刷新。
public struct IdleTimeStatusBarPopover: View {
    @StateObject private var vm = AppIdleTimeVM()

    public init() {}

    public var body: some View {
        IdlePopoverView(snapshot: vm.snapshot)
    }
}
