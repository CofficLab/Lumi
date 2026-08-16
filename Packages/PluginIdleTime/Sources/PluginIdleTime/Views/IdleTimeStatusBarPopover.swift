import ProviderIdleTime
import SwiftUI

/// 菜单栏弹窗：实时展示 Idle Time 快照。
///
/// 由旧版 `Plugins/IdleTimePlugin/Sources/Views/IdleTimeStatusBarPopover.swift`
/// 迁移而来，差异：provider 由插件注入（替代旧版默认 `IdleTimeService.shared`）。
public struct IdleTimeStatusBarPopover: View {
    @StateObject private var vm: AppIdleTimeVM

    public init(provider: (any IdleTimeProviding)?) {
        _vm = StateObject(wrappedValue: AppIdleTimeVM(provider: provider))
    }

    public var body: some View {
        IdlePopoverView(snapshot: vm.snapshot)
    }
}
