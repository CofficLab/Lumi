import SwiftUI
import LumiUI
import LumiKernel
import AppKit

/// Idle Time 设置页:展示推断出的“休息窗口”与活动热度。
///
/// 通过 `AppIdleTimeVM` 实时订阅 `IdleTimeService` 的快照变化,
/// 复用 `IdlePopoverView` 的展示内容。右上角提供“打开数据目录”按钮,
/// 在 Finder 中打开本插件本地数据库(活动记录)所在位置,
/// 与 Project RAG 插件的设置页行为一致。
@MainActor
public struct IdleTimeSettingsView: View {
    let kernel: LumiKernel
    @StateObject private var vm = AppIdleTimeVM()
    @LumiTheme private var theme

    public init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                IdlePopoverView(snapshot: vm.snapshot)
            }
            .padding(20)
        }
        .frame(minWidth: 520, minHeight: 440)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Spacer()
            AppButton("Open Data Directory", systemImage: "folder", size: .small) {
                openDataDirectory()
            }
        }
        .font(.appCaption)
        .foregroundStyle(theme.textSecondary)
    }

    // MARK: - Helpers

    /// 在 Finder 中打开本插件的磁盘数据目录(活动记录数据库所在位置)。
    private func openDataDirectory() {
        let url = kernel.storage?.pluginDataDirectory(for: "IdleTime")
            ?? IdleTimeRuntimeBridge.directoryURL
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        _ = NSWorkspace.shared.open(url)
    }
}
