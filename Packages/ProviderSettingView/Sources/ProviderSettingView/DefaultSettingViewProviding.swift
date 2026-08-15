import SwiftUI

/// `SettingViewProviding` 的默认实现：返回一个最简单的设置视图。
///
/// 骨架阶段使用：仅展示一个设置占位面板，用于验证
/// 「内核 → 工厂 → App → 设置窗口」链路。宿主可注入自己的实现
/// （如基于 Lumi SettingsView 的完整设置界面）。
@MainActor
public final class DefaultSettingViewProviding: SettingViewProviding {
    public init() {}

    public func makeSettingView() -> AnyView {
        AnyView(
            VStack(spacing: 12) {
                Image(systemName: "gearshape")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Settings")
                    .font(.title2)
                Text("Settings view provided by SettingViewProviding")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
    }
}
