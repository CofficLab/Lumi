import KernelCore
import ProviderSettingView
import SwiftUI

/// 设置 - 通用 插件
///
/// 在设置视图中注册「通用」入口，详情展示当前 App 版本。
///
/// 通过 `SuperPlugin.onBoot(kernel:)` 解析内核中的 `SettingViewProviding`，
/// 用 `addEntries(_:)`（追加语义）注册入口，不覆盖其他插件贡献的入口。
@MainActor
public final class SettingGeneralPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.setting-general"
    public let order = 100

    /// 版本字符串提供器；默认读取 App bundle 版本，可注入以便测试。
    private let versionProvider: @MainActor () -> String?

    public init(versionProvider: @escaping @MainActor () -> String? = { AppVersion.current }) {
        self.versionProvider = versionProvider
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let settings = kernel.resolveProvider((any SettingViewProviding).self) else {
            // 设置视图未注册：优雅降级，不贡献入口。
            return
        }

        let entry = SettingEntryItem(
            id: "general",
            title: "通用",
            systemImage: "gearshape",
            order: 100
        ) { [versionProvider] in
            GeneralSettingsDetailView(version: versionProvider())
        }

        settings.addEntries([entry])
    }
}

/// 通用设置详情视图：展示当前 App 版本。
private struct GeneralSettingsDetailView: View {
    let version: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("通用")
                .font(.title2)

            GroupBox("关于") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text(version ?? "未知")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
