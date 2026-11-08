import Combine
import Foundation

/// Dashboard 的可刷新应用列表。
///
/// 读取闭包可注入，方便测试「启动/退出后重新计算」的行为。
@MainActor
final class NettoRunningAppsStore: ObservableObject {
    @Published private(set) var apps: [SmartApp]

    private let load: () -> [SmartApp]

    init(load: @escaping () -> [SmartApp] = { SmartApp.runningApps() }) {
        self.load = load
        self.apps = load()
    }

    /// 重新读取当前运行中的应用。
    func refresh() {
        apps = load()
    }
}
