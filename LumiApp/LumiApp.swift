import AppKit
import AppUpdatePlugin
import Darwin
import FactoryLumi
import KernelCore
import KitBootstrapEnvironment
import os
import PluginToast
import PluginToolbarSettings
import ProviderSettingView
import ProviderToast
import SwiftUI

/// 提升进程的文件描述符上限。
///
/// macOS App 的默认 soft limit 通常只有 256，对于长时间运行且频繁执行
/// 工具调用（每次 `Process` + `Pipe` 消耗 4+ fds）和网络请求的 agent 应用，
/// 很容易在持续对话后耗尽 fd，导致 `"Too many open files"` (EMFILE) 错误。
///
/// 将 soft limit 提升到 10240（或 hard limit 的较小值），为 agent 工作负载
/// 提供充足的 fd 余量。
private func raiseFileDescriptorLimit() {
    var limit = rlimit()
    guard getrlimit(RLIMIT_NOFILE, &limit) == 0 else { return }

    let target: UInt64 = 10_240
    let newSoft = min(target, limit.rlim_max)
    guard newSoft > limit.rlim_cur else { return }

    limit.rlim_cur = newSoft
    if setrlimit(RLIMIT_NOFILE, &limit) == 0 {
        Logger(subsystem: "com.coffic.lumi", category: "bootstrap")
            .info("Raised RLIMIT_NOFILE to \(newSoft)")
    }
}

@main
struct LumiApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: LumiAppDelegate
    private let kernel: KernelCoreContainer
    @StateObject private var menuBarController: LumiMenuBarController
    private let toastCenter: ToastCenter?

    /// 启动前探测到的磁盘空间判定结果。
    ///
    /// 启动成功但空间不足时，用它给一个需要用户手动关闭的警告；启动失败时，
    /// 用它把失败归因成「磁盘空间不足」。
    private let spaceVerdict: BootstrapSpaceVerdict

    /// 应用数据目录，同时也是磁盘预检的探测目标。
    private static var applicationSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return base.appendingPathComponent(bundleID, isDirectory: true)
    }

    /// 从原始错误里抽取启动失败的上下文。
    ///
    /// `KernelCoreError` 已经带了归属信息（插件 ID + 生命周期阶段），把它拆出来，
    /// 错误页才能说清「是哪个插件、在哪个阶段失败」，而不是只甩一句原文。
    private static func failureContext(for error: Error) -> BootstrapFailureContext {
        let attribution = (error as? KernelCoreError)?.lifecycleAttribution
        let detail = error.localizedDescription
        return BootstrapFailureContext(
            pluginID: attribution?.pluginID,
            phase: attribution?.phase,
            technicalDetail: detail.isEmpty ? String(describing: error) : detail
        )
    }

    /// 主视图在 `init` 中一次性装配并缓存，绝不能在 `body` 求值期间调用
    /// `makeMainView(kernel:)`：它会向 `DefaultRootViewProviding`
    /// （ObservableObject）的 `@Published` 属性注入视图，在视图更新期间发布
    /// `objectWillChange` 会触发 SwiftUI 的 "Publishing changes from within
    /// view updates is not allowed"，因此不能在 `body` 求值期间反复装配。
    private let mainView: AnyView

    /// 设置视图同样在 `init` 中装配一次（避免每个窗口重复装配内核贡献）。
    private let settingsView: AnyView

    @Environment(\.openWindow) private var openWindow

    init() {
        // 提升 fd 上限，避免长时间 agent 会话后因 EMFILE 导致网络/工具同时失败
        raiseFileDescriptorLimit()

        // 启动前先探测磁盘可用空间。
        //
        // SwiftData 会把底层 SQLite 失败（`database or disk is full`）一律折叠成
        // `SwiftDataError code 1` + 空 userInfo，真正的 errno 只出现在 CoreData 写到
        // 统一日志的那一行里——应用自己的错误链拿不到「磁盘满」这个根因。
        // 所以必须在装配内核**之前**主动探测卷容量，才能在插件失败时给出
        // 「磁盘空间不足」这种用户看得懂、也知道怎么做的提示。
        let space = BootstrapEnvironment.evaluateSpace(at: Self.applicationSupportDirectory)
        spaceVerdict = space

        do {
            // 先在属性初始化阶段完成可能失败的装配。
            let assembledKernel = try KernelFactory.makeKernel()
            kernel = assembledKernel
            _menuBarController = StateObject(wrappedValue: LumiMenuBarController())
            toastCenter = assembledKernel.resolveProvider((any ToastProviding).self) as? ToastCenter
            // Register the host-owned update provider before the settings view
            // is materialized, so General can render the channel selector.
            AppUpdateBootstrap.start(kernel: assembledKernel)
            mainView = (try? KernelFactory.makeMainView(kernel: assembledKernel))
                ?? AnyView(BootstrapFailureView(
                    failure: BootstrapFailureReport(
                        kind: .unknown,
                        technicalDetail: "Failed to assemble main view"
                    ),
                    dataDirectory: Self.applicationSupportDirectory
                ))
            settingsView = (try? KernelFactory.makeSettingsView(kernel: assembledKernel))
                ?? AnyView(BootstrapFailureView(
                    failure: BootstrapFailureReport(
                        kind: .unknown,
                        technicalDetail: "Failed to assemble settings view"
                    ),
                    dataDirectory: Self.applicationSupportDirectory
                ))
        } catch {
            // 启动失败必须显式呈现，不能静默退化成一个没有 Provider 的空内核。
            // 但也不能把原始报错字符串直接甩给用户——那在 SwiftData 那一层就已经
            // 退化成了「未能完成操作。(SwiftData.SwiftDataError 错误。)」，
            // 原样展示等于什么都没告诉用户。这里先归因，再展示。
            kernel = KernelCoreContainer()
            _menuBarController = StateObject(wrappedValue: LumiMenuBarController())
            toastCenter = nil
            let report = BootstrapFailureClassifier.classify(
                context: Self.failureContext(for: error),
                space: space
            )
            mainView = AnyView(BootstrapFailureView(
                failure: report,
                dataDirectory: Self.applicationSupportDirectory
            ))
            settingsView = AnyView(BootstrapFailureView(
                failure: report,
                dataDirectory: Self.applicationSupportDirectory
            ))
        }
    }

    var body: some Scene {
        // Lumi is a single-workspace app. `WindowGroup` would allow users to
        // create additional main windows through Dock reactivation, the New
        // Window command, or repeated scene activation.
        Window("Lumi", id: "lumi.main") {
            // App 只做一件事：让 Factory 给一个视图。
            // 主窗口 / 设置窗口 / 菜单栏共享同一内核（kernel），
            // 主题切换后各窗口即时同步。
            // 注意：`.onReceive` 需应用到整个 `??` 表达式（否则会误绑到 fallback 分支）。
            ToastHost(
                content: mainView,
                center: toastCenter
            )
            // 与旧版 Lumi（WindowMain.configureForLumiMainChrome）一致：
            // 窗口内容延伸到标题栏区域（fullSizeContentView），
            // 工具栏从窗口顶部开始渲染，红绿灯悬浮在工具栏上。
            .background {
                WindowAccessor { window in
                    window.configureForLumiMinimalChrome()
                }
            }
            // 工具栏「设置」或其他深链动作发出通知后，打开设置窗口。
            .onReceive(NotificationCenter.default.publisher(for: SettingViewNavigation.openSettingsNotification)) { notification in
                if let settings = kernel.resolveProvider((any SettingViewProviding).self),
                   let entryID = notification.userInfo?[SettingViewNavigation.entryIDUserInfoKey] as? String,
                   settings.entries.contains(where: { $0.id == entryID }) {
                    settings.selectEntry(id: entryID)
                }
                openWindow(id: "lumi.settings")
            }
            .onReceive(appDelegate.$pendingOpenPath.compactMap { $0 }) { path in
                consumePendingOpenPath(path, kernel: kernel)
            }
            .onAppear {
                menuBarController.install(kernel: kernel)
                warnIfDiskSpaceLow()
                // Launch Services may deliver a file before the main window
                // has installed its Combine subscription. Consume the
                // retained delegate value once the V2 window is ready.
                if let path = appDelegate.pendingOpenPath {
                    consumePendingOpenPath(path, kernel: kernel)
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        // Preserve the legacy `AppBootstrap.defaultWindowSize` so existing
        // workspace, rail, chat, and plugin layouts open at their familiar
        // usable dimensions instead of the temporary minimal-host size.
        .defaultSize(width: 1100, height: 760)
        .commands {
            AppCommands(kernel: kernel) {
                UpdateService.shared.checkForUpdates()
            }
        }

        Window("设置", id: "lumi.settings") {
            settingsView
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        // Preserve the legacy `AppBootstrap.defaultSettingsWindowSize`.
        .defaultSize(width: 800, height: 500)
    }

    /// 启动成功、但磁盘空间不足以可靠工作时，给一个需要用户手动关闭的警告。
    ///
    /// 这种情况下应用还能起来，但插件随时可能因为 SQLite 写入失败而报错；
    /// 与其等用户撞上「插件启动失败」这种看不懂的报错，不如提前说清楚。
    ///
    /// - Important: `ToastCenter` 是 `@MainActor`，这里必须显式标注，
    ///   否则 Swift 6 严格并发下会报「call to main actor-isolated instance method
    ///   in a synchronous nonisolated context」。
    @MainActor
    private func warnIfDiskSpaceLow() {
        guard case .insufficient(let availableBytes, let requiredBytes) = spaceVerdict else { return }
        toastCenter?.presentError(
            title: "磁盘空间不足",
            message: "Lumi 至少需要 \(BootstrapByteFormat.string(requiredBytes)) 的可用磁盘空间，"
                + "当前只剩 \(BootstrapByteFormat.string(availableBytes))。"
                + "空间不足会导致插件启动失败或数据写入失败，请尽快清理磁盘。",
            sourceWindowID: nil
        )
    }

    /// 与旧版 `MenuBarManagerPlugin.showMainWindow()` 保持相同行为：从状态栏
    /// 弹窗唤回应用，并把可成为 key 的主窗口置前。
    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.identifier == LumiWindowIdentity.main }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func consumePendingOpenPath(_ path: String, kernel: KernelCoreContainer) {
        guard appDelegate.pendingOpenPath == path else { return }
        appDelegate.pendingOpenPath = nil
        Task { @MainActor in
            _ = await KernelFactory.openExternalPath(path, kernel: kernel)
        }
    }
}

/// 内核装配失败时的兜底视图。
///
/// - Important: 此视图在内核装配失败后渲染，必须**完全自足**：
///   不得使用 `@LumiTheme` / `AppUI.*` 等依赖 ThemeProviding 解析结果的
///   LumiUI 组件，否则主题 Provider 缺失会二次崩溃，导致连错误页都显示不出来。
///   因此这里只使用 SwiftUI 语义色与 SF Symbols。
private struct BootstrapFailureView: View {
    let failure: BootstrapFailureReport
    let dataDirectory: URL

    /// 技术详情默认是否展开。
    ///
    /// 磁盘不足时标题已经说清了「该做什么」，原始报错收起来；其余情况仍然
    /// 默认展开，保持「一键看到原始报错」的老行为。
    @State private var showsTechnicalDetail: Bool

    init(failure: BootstrapFailureReport, dataDirectory: URL) {
        self.failure = failure
        self.dataDirectory = dataDirectory
        _showsTechnicalDetail = State(initialValue: {
            switch failure.kind {
            case .insufficientDiskSpace: return false
            case .pluginBootFailed, .unknown: return true
            }
        }())
    }

    var body: some View {
        VStack(spacing: 24) {
            badge

            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.primary)

            explanation

            actions

            technicalDetails
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 标题按归因结果分级：磁盘不足要说「磁盘空间不足」，而不是「启动失败」。
    private var title: String {
        switch failure.kind {
        case .insufficientDiskSpace:
            return "磁盘空间不足"
        case .pluginBootFailed:
            return "插件启动失败"
        case .unknown:
            return "LumiMinimal 启动失败"
        }
    }

    /// 一句话说清「发生了什么、接下来该做什么」。
    private var explanation: some View {
        Text(explanationText)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 460, alignment: .leading)
    }

    private var explanationText: String {
        switch failure.kind {
        case .insufficientDiskSpace(let availableBytes, let requiredBytes):
            return "Lumi 至少需要 \(BootstrapByteFormat.string(requiredBytes)) 的可用磁盘空间才能启动，"
                + "当前只剩 \(BootstrapByteFormat.string(availableBytes))。"
                + "释放磁盘空间后重新启动即可——数据目录里通常藏着可以清理的大文件。"
        case .pluginBootFailed:
            let plugin = failure.pluginID.map { "「\($0)」" } ?? "某个插件"
            return "插件 \(plugin) 在\(phaseDescription(failure.phase))阶段失败。"
                + "原始报错在下方技术详情里，可复制后排查。"
        case .unknown:
            return "启动过程中发生未预期的错误。原始报错在下方技术详情里，可复制后排查。"
        }
    }

    /// 把 KernelCore 的生命周期阶段名翻译成人话。
    private func phaseDescription(_ phase: String?) -> String {
        switch phase {
        case "boot": return "启动"
        case "ready": return "就绪"
        case .some(let other): return other
        case nil: return "启动"
        }
    }

    /// 可操作动作。
    ///
    /// 内核此时还没装配成功，不能依赖任何 Provider，所以这里的动作全部走
    /// AppKit / Foundation：访达、重新启动、退出、复制。
    private var actions: some View {
        HStack(spacing: 12) {
            switch failure.kind {
            case .insufficientDiskSpace:
                Button("在访达中打开数据目录") { self.openDataDirectory() }
                    .buttonStyle(.borderedProminent)
                Button("重新启动") { self.relaunch() }
                    .buttonStyle(.bordered)
                Button("退出") { self.terminateApp() }
                    .buttonStyle(.bordered)
            case .pluginBootFailed, .unknown:
                Button("复制技术详情") { self.copyTechnicalDetail() }
                    .buttonStyle(.borderedProminent)
                Button("退出") { self.terminateApp() }
                    .buttonStyle(.bordered)
            }
        }
    }

    /// 技术详情：等宽字体 + 可选中，便于用户复制去排查。
    private var technicalDetails: some View {
        DisclosureGroup(isExpanded: $showsTechnicalDetail) {
            detailCard
        } label: {
            Label("技术详情", systemImage: "doc.text.magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 460)
    }

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let pluginID = failure.pluginID {
                Text("插件：\(pluginID)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if let phase = failure.phase {
                Text("阶段：\(phase)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Text(failure.technicalDetail)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: 460)
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.separator.opacity(0.6), lineWidth: 1)
        }
    }

    // MARK: - 动作实现

    private func openDataDirectory() {
        try? FileManager.default.createDirectory(
            at: dataDirectory,
            withIntermediateDirectories: true
        )
        NSWorkspace.shared.open(dataDirectory)
    }

    private func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(
            at: Bundle.main.bundleURL,
            configuration: configuration
        ) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    private func terminateApp() {
        NSApp.terminate(nil)
    }

    private func copyTechnicalDetail() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(failure.technicalDetail, forType: .string)
    }

    /// 图标徽章：圆形渐变底 + 白色警告符号，替代系统默认的灰色描边图标。
    private var badge: some View {
        ZStack {
            // 背景光晕：用大尺寸三角模糊铺在徽章后方，营造柔和的暖色氛围。
            // 放在 .background 而非 .overlay，避免半透明色叠加导致徽章发浑。
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 132))
                .foregroundStyle(.orange.opacity(0.10))
                .blur(radius: 10)
                .offset(y: 4)
                .allowsHitTesting(false)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.orange, Color.red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 96, height: 96)
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1)
                }
                .shadow(color: .red.opacity(0.28), radius: 18, y: 8)

            Image(systemName: "exclamationmark")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.white)
        }
        .accessibilityHidden(true)
    }

}

/// 挂载 V2 ToastCenter，使插件和服务发出的提示真正呈现在主窗口上。
private struct ToastHost<Content: View>: View {
    let content: Content
    let center: ToastCenter?

    var body: some View {
        if let center {
            ToastOverlay(content: content, center: center)
        } else {
            content
        }
    }
}
