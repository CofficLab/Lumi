import Foundation
import LumiCoreKit
import os
import SwiftUI

enum OnboardingPageIndexing {
    static func clampedIndex(_ index: Int, pageCount: Int) -> Int {
        guard pageCount > 0 else { return 0 }
        return min(max(index, 0), pageCount - 1)
    }
}

// MARK: - ViewModel

@MainActor
public final class OnboardingPluginViewModel: ObservableObject {
    // MARK: - 属性

    @Published var isPresentingOnboarding = false
    @Published var currentStep = 0
    @Published var isTransitioning = false
    @Published var persistenceErrorMessage: String?

    private let store: OnboardingPluginStore

    // MARK: - 初始化

    public init(store: OnboardingPluginStore = .init(pluginId: "Onboarding")) {
        self.store = store
    }

    // MARK: - 计算属性

    private var hasCompletedOnboarding: Bool {
        store.completed
    }

    // MARK: - 公开方法

    public func presentIfNeededOnLaunch() {
        guard !hasCompletedOnboarding else { return }
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        start()
    }

    public func start() {
        currentStep = 0
        isPresentingOnboarding = true
    }

    public func show(forceReset: Bool) {
        if forceReset {
            guard store.setCompleted(false) else {
                persistenceErrorMessage = LumiPluginLocalization.string("无法重置新手引导状态，请检查 Lumi 的数据目录是否可写。", bundle: .module)
                return
            }
        }
        start()
    }

    public func skip() {
        complete()
    }

    public func complete() {
        guard store.setCompleted(true) else {
            persistenceErrorMessage = LumiPluginLocalization.string("无法保存新手引导状态，请检查 Lumi 的数据目录是否可写。", bundle: .module)
            return
        }
        isPresentingOnboarding = false
        currentStep = 0
    }

    public func nextStep(totalSteps: Int) {
        guard totalSteps > 0 else {
            complete()
            return
        }
        guard !isTransitioning else { return }

        currentStep = OnboardingPageIndexing.clampedIndex(currentStep, pageCount: totalSteps)
        if currentStep >= totalSteps - 1 {
            complete()
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isTransitioning = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.currentStep = OnboardingPageIndexing.clampedIndex(self.currentStep + 1, pageCount: totalSteps)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    self.isTransitioning = false
                }
            }
        }
    }

    public func previousStep() {
        guard !isTransitioning else { return }
        guard currentStep > 0 else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isTransitioning = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.currentStep = max(self.currentStep - 1, 0)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.isTransitioning = false
            }
        }
    }
}

// MARK: - Store

public final class OnboardingPluginStore {
    // MARK: - 属性

    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.onboarding.store")
    private let fileManager = FileManager.default
    private let settingsURL: URL
    private let stateFileURL: URL
    private let corruptStateFileURL: URL

    // MARK: - 初始化

    public init(pluginId: String) {
        let root = AppConfig.getDBFolderURL()
            .appendingPathComponent(pluginId, isDirectory: true)
        self.settingsURL = root.appendingPathComponent("settings", isDirectory: true)
        self.stateFileURL = settingsURL.appendingPathComponent("onboarding_state.plist")
        self.corruptStateFileURL = settingsURL.appendingPathComponent("onboarding_state.corrupt.plist")
        prepareDirectories()
    }

    init(settingsDirectory: URL) {
        self.settingsURL = settingsDirectory
        self.stateFileURL = settingsURL.appendingPathComponent("onboarding_state.plist")
        self.corruptStateFileURL = settingsURL.appendingPathComponent("onboarding_state.corrupt.plist")
        prepareDirectories()
    }

    // MARK: - 公开方法

    public var completed: Bool {
        get { readCompletedFlag() }
        set { setCompleted(newValue) }
    }

    @discardableResult
    public func setCompleted(_ completed: Bool) -> Bool {
        writeCompletedFlag(completed)
    }

    // MARK: - 私有方法

    private func prepareDirectories() {
        do {
            try fileManager.createDirectory(at: settingsURL, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("Create onboarding settings directory failed: \(error.localizedDescription)")
        }
    }

    private func readCompletedFlag() -> Bool {
        guard fileManager.fileExists(atPath: stateFileURL.path) else {
            return false
        }

        do {
            let data = try Data(contentsOf: stateFileURL)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dict = plist as? [String: Any] else {
                Self.logger.error("Read onboarding state failed: root plist is not a dictionary")
                quarantineCorruptState()
                return false
            }
            return dict["completed"] as? Bool ?? false
        } catch {
            Self.logger.error("Read onboarding state failed: \(error.localizedDescription)")
            quarantineCorruptState()
            return false
        }
    }

    @discardableResult
    private func writeCompletedFlag(_ completed: Bool) -> Bool {
        let payload: [String: Any] = [
            "completed": completed,
            "updatedAt": Date()
        ]

        let data: Data
        do {
            data = try PropertyListSerialization.data(fromPropertyList: payload, format: .binary, options: 0)
        } catch {
            Self.logger.error("Encode onboarding state failed: \(error.localizedDescription)")
            return false
        }

        let tempURL = settingsURL.appendingPathComponent("onboarding_state.tmp")
        do {
            try fileManager.createDirectory(at: settingsURL, withIntermediateDirectories: true)
            try data.write(to: tempURL, options: .atomic)
            if fileManager.fileExists(atPath: stateFileURL.path) {
                _ = try fileManager.replaceItemAt(stateFileURL, withItemAt: tempURL)
            } else {
                try fileManager.moveItem(at: tempURL, to: stateFileURL)
            }
            return true
        } catch {
            Self.logger.error("Persist onboarding state failed: \(error.localizedDescription)")
            try? fileManager.removeItem(at: tempURL)
            return false
        }
    }

    private func quarantineCorruptState() {
        guard fileManager.fileExists(atPath: stateFileURL.path) else { return }

        do {
            if fileManager.fileExists(atPath: corruptStateFileURL.path) {
                try fileManager.removeItem(at: corruptStateFileURL)
            }
            try fileManager.moveItem(at: stateFileURL, to: corruptStateFileURL)
        } catch {
            Self.logger.error("Quarantine corrupt onboarding state failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - RootOverlay

public struct OnboardingRootOverlay<Content: View>: View {
    public let content: Content

    @StateObject private var viewModel = OnboardingPluginViewModel()

    public var body: some View {
        content
            .onAppear {
                viewModel.presentIfNeededOnLaunch()
            }
            .onReceive(NotificationCenter.default.publisher(for: .lumiShowOnboarding)) { notification in
                let forceReset = notification.userInfo?[LumiOnboardingNotification.resetKey] as? Bool ?? false
                viewModel.show(forceReset: forceReset)
            }
            .sheet(isPresented: $viewModel.isPresentingOnboarding) {
                OnboardingSheetView(viewModel: viewModel)
            }
    }
}

// MARK: - SheetView

private struct OnboardingSheetView: View {
    @ObservedObject var viewModel: OnboardingPluginViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedPluginIDs: Set<String> = []
    @State private var hasLoadedPluginSelection = false

    // MARK: - 页面数据

    private struct OnboardingPage: Identifiable {
        let id: String
        let icon: String
        let iconGradient: [Color]
        let title: String
        let subtitle: String
        let features: [Feature]
        let tip: String?
    }

    private struct OnboardingPluginOption: Identifiable {
        let id: String
        let name: String
        let description: String
        let icon: String
        let defaultEnabled: Bool
    }

    private struct Feature {
        let icon: String
        let title: String
        let description: String
    }

    private var configurablePlugins: [OnboardingPluginOption] {
        []
    }

    private var pages: [OnboardingPage] {
        var items = [
            OnboardingPage(
                id: "welcome",
                icon: "sparkles",
                iconGradient: [Color.blue, Color.purple],
                title: "欢迎使用 Lumi",
                subtitle: "你的 AI 驱动个人桌面助手",
                features: [
                    Feature(
                        icon: "brain",
                        title: "智能对话",
                        description: LumiPluginLocalization.string("支持本地和云端 LLM，智能处理复杂任务", bundle: .module)
                    ),
                    Feature(
                        icon: "hammer.circle",
                        title: "Agent 能力",
                        description: LumiPluginLocalization.string("自动执行文件操作、命令行、Git 等任务", bundle: .module)
                    ),
                    Feature(
                        icon: "rectangle.3.group",
                        title: "多会话并行",
                        description: LumiPluginLocalization.string("同时处理多个独立任务，互不干扰", bundle: .module)
                    )
                ],
                tip: nil
            ),
            OnboardingPage(
                id: "project-context",
                icon: "folder.badge.gearshape",
                iconGradient: [Color.orange, Color.red],
                title: "项目与上下文",
                subtitle: "让 AI 理解你的代码和项目结构",
                features: [
                    Feature(
                        icon: "arrow.down.doc",
                        title: "拖拽添加项目",
                        description: LumiPluginLocalization.string("将文件夹拖入对话区即可设为当前项目", bundle: .module)
                    ),
                    Feature(
                        icon: "doc.text.magnifyingglass",
                        title: "智能上下文",
                        description: LumiPluginLocalization.string("自动分析项目结构、代码依赖和文件内容", bundle: .module)
                    ),
                    Feature(
                        icon: "chevron.left.slash.chevron.right",
                        title: "代码选区",
                        description: LumiPluginLocalization.string("在编辑器中选中代码，Lumi 会自动获取选中内容", bundle: .module)
                    )
                ],
                tip: "最近使用的项目会自动保存，方便快速切换"
            ),
            OnboardingPage(
                id: "agent-tools",
                icon: "wand.and.stars",
                iconGradient: [Color.purple, Color.pink],
                title: "Agent 工具执行",
                subtitle: "让 AI 不仅仅是聊天，更能真正帮你完成任务",
                features: [
                    Feature(
                        icon: "terminal",
                        title: "命令执行",
                        description: LumiPluginLocalization.string("在安全沙箱中执行 Shell 命令，自动处理权限请求", bundle: .module)
                    ),
                    Feature(
                        icon: "doc.badge.gearshape",
                        title: "文件操作",
                        description: LumiPluginLocalization.string("读取、创建、编辑文件，自动保存更改", bundle: .module)
                    ),
                    Feature(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Git 集成",
                        description: LumiPluginLocalization.string("查看仓库状态、提交历史，协助代码管理", bundle: .module)
                    )
                ],
                tip: "高风险操作会请求你的确认，确保安全可靠"
            ),
            OnboardingPage(
                id: "plugins",
                icon: "puzzlepiece.extension",
                iconGradient: [Color.cyan, Color.blue],
                title: "插件系统",
                subtitle: "通过插件扩展 Lumi 的无限可能",
                features: [
                    Feature(
                        icon: "gearshape.2",
                        title: "内置插件",
                        description: LumiPluginLocalization.string("文件浏览器、最近项目、设置中心等开箱即用", bundle: .module)
                    ),
                    Feature(
                        icon: "arrow.up.bin",
                        title: "灵活启用/禁用",
                        description: LumiPluginLocalization.string("在设置中按需管理插件，优化性能和体验", bundle: .module)
                    ),
                    Feature(
                        icon: "square.and.arrow.up",
                        title: "Finder 集成",
                        description: LumiPluginLocalization.string("右键菜单快速操作，与 Finder 无缝协作", bundle: .module)
                    )
                ],
                tip: "更多插件可在设置中心的「插件」标签页管理"
            ),
            OnboardingPage(
                id: "quick-start",
                icon: "gearshape",
                iconGradient: [Color.gray, Color.secondary],
                title: "快速开始",
                subtitle: "完成设置，开始你的 AI 之旅",
                features: [
                    Feature(
                        icon: "cpu",
                        title: "选择模型",
                        description: LumiPluginLocalization.string("配置本地模型或云端 API，选择适合你的 AI 引擎", bundle: .module)
                    ),
                    Feature(
                        icon: "paintpalette",
                        title: "自定义主题",
                        description: LumiPluginLocalization.string("深色/浅色模式，多种主题风格随心切换", bundle: .module)
                    ),
                    Feature(
                        icon: "plus.circle",
                        title: "创建会话",
                        description: LumiPluginLocalization.string("点击新建按钮或按 ⌘N，开始第一个对话", bundle: .module)
                    )
                ],
                tip: "所有设置均可随时在设置中心调整"
            )
        ]

        if !configurablePlugins.isEmpty,
           let quickStartIndex = items.firstIndex(where: { $0.id == "quick-start" }) {
            items.insert(
                OnboardingPage(
                    id: "plugin-selection",
                    icon: "puzzlepiece.extension.fill",
                    iconGradient: [Color.indigo, Color.cyan],
                    title: LumiPluginLocalization.string("选择你的插件", bundle: .module),
                    subtitle: LumiPluginLocalization.string("先启用常用扩展，之后也可以在设置中调整", bundle: .module),
                    features: [],
                    tip: LumiPluginLocalization.string("插件选择会在完成引导后立即生效", bundle: .module)
                ),
                at: quickStartIndex
            )
        }

        return items
    }

    // MARK: - Body

    public var body: some View {
        let pageIndex = safePageIndex
        let page = pages[pageIndex]
        let isLastPage = pageIndex == pages.count - 1

        ZStack {
            // 背景渐变
            backgroundGradient

            // 主内容
            VStack(spacing: 0) {
                // 顶部导航栏
                topBar

                // 分隔线
                Divider()
                    .opacity(0.5)

                // 内容区域
                ScrollView(.vertical, showsIndicators: false) {
                    pageContent(page)
                        .padding(.horizontal, 32)
                        .padding(.top, 24)
                        .padding(.bottom, 16)
                }

                // 底部分隔线
                Divider()
                    .opacity(0.5)

                // 底部操作栏
                bottomBar(isLastPage: isLastPage)
            }
        }
        .frame(width: 780, height: 560)
        .background(.clear)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(colorScheme == .dark ? 0.15 : 0.3),
                            .white.opacity(colorScheme == .dark ? 0.05 : 0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.5 : 0.2),
            radius: 40,
            x: 0,
            y: 20
        )
        .interactiveDismissDisabled()
            .onAppear {
                loadPluginSelectionIfNeeded()
            }
            .alert(
                LumiPluginLocalization.string("无法保存新手引导状态", bundle: .module),
                isPresented: Binding(
                    get: { viewModel.persistenceErrorMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            viewModel.persistenceErrorMessage = nil
                        }
                    }
                )
            ) {
                Button(LumiPluginLocalization.string("好", bundle: .module), role: .cancel) {}
            } message: {
                Text(viewModel.persistenceErrorMessage ?? "")
            }
    }

    // MARK: - 子视图

    /// 背景渐变
    private var backgroundGradient: some View {
        let page = pages[safePageIndex]
        return LinearGradient(
            colors: [
                page.iconGradient[0].opacity(colorScheme == .dark ? 0.08 : 0.04),
                page.iconGradient[1].opacity(colorScheme == .dark ? 0.05 : 0.02),
                .clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    /// 顶部导航栏
    private var topBar: some View {
        HStack {
            Label(LumiPluginLocalization.string("新手引导", bundle: .module), systemImage: "graduationcap.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer()

            // 步骤指示器
            stepIndicator

            Spacer()

            // 跳过按钮
            Button(LumiPluginLocalization.string("跳过", bundle: .module)) {
                viewModel.skip()
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.quinary.opacity(0.5))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    /// 步骤指示器
    private var stepIndicator: some View {
        let pageIndex = safePageIndex

        return HStack(spacing: 6) {
            ForEach(0..<pages.count, id: \.self) { index in
                Capsule()
                    .fill(
                        index == pageIndex
                            ? pages[pageIndex].iconGradient[0]
                            : index < pageIndex
                                ? .secondary.opacity(0.4)
                                : .secondary.opacity(0.15)
                    )
                    .frame(
                        width: index == pageIndex ? 24 : 8,
                        height: 6
                    )
                    .animation(
                        .spring(response: 0.3, dampingFraction: 0.8),
                        value: viewModel.currentStep
                    )
            }
        }
    }

    /// 页面内容
    private func pageContent(_ page: OnboardingPage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 图标和标题
            headerSection(page)

            if page.id == "plugin-selection" {
                pluginSelectionSection
                    .padding(.top, 28)
            } else {
                // 功能特性列表
                featuresSection(page)
                    .padding(.top, 28)
            }

            // 提示卡片
            if let tip = page.tip {
                tipCard(tip)
                    .padding(.top, 24)
            }

            Spacer(minLength: 0)
        }
        .opacity(viewModel.isTransitioning ? 0 : 1)
        .offset(x: viewModel.isTransitioning ? -20 : 0)
    }

    private var pluginSelectionSection: some View {
        VStack(spacing: 12) {
            ForEach(configurablePlugins) { plugin in
                pluginSelectionRow(plugin)
            }
        }
    }

    private func pluginSelectionRow(_ plugin: OnboardingPluginOption) -> some View {
        let isSelected = selectedPluginIDs.contains(plugin.id)

        return Button {
            togglePluginSelection(plugin.id)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.quinary.opacity(0.5))
                        .frame(width: 36, height: 36)

                    Image(systemName: plugin.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(plugin.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(plugin.description)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? .green : .secondary.opacity(0.6))
            }
            .padding(14)
            .contentShape(Rectangle())
            .background(.quinary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// 头部区域
    private func headerSection(_ page: OnboardingPage) -> some View {
        HStack(spacing: 20) {
            // 图标容器
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: page.iconGradient.map { $0.opacity(0.15) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: page.icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: page.iconGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(page.subtitle)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    /// 功能特性区域
    private func featuresSection(_ page: OnboardingPage) -> some View {
        VStack(spacing: 12) {
            ForEach(page.features.indices, id: \.self) { index in
                let feature = page.features[index]
                featureRow(feature, isLast: index == page.features.count - 1)
            }
        }
    }

    /// 单个功能行
    private func featureRow(_ feature: Feature, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    // 特性图标
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.quinary.opacity(0.5))
                            .frame(width: 36, height: 36)

                        Image(systemName: feature.icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(feature.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(feature.description)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }
            }
            .padding(14)
            .background(.quinary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if !isLast {
                Divider()
                    .opacity(0.3)
            }
        }
    }

    /// 提示卡片
    private func tipCard(_ tip: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14))
                .foregroundStyle(.yellow)

            Text(tip)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.yellow.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.yellow.opacity(0.2), lineWidth: 1)
                )
        )
    }

    /// 底部操作栏
    private func bottomBar(isLastPage: Bool) -> some View {
        HStack {
            // 上一步按钮
            if viewModel.currentStep > 0 {
                Button {
                    viewModel.previousStep()
                } label: {
                    Label(LumiPluginLocalization.string("上一步", bundle: .module), systemImage: "chevron.left")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.quinary.opacity(0.5))
                .clipShape(Capsule())
            }

            Spacer()

            // 下一步/开始使用按钮
            Button {
                if isLastPage {
                    completeOnboarding()
                } else {
                    viewModel.nextStep(totalSteps: pages.count)
                }
            } label: {
                HStack(spacing: 6) {
                    Text(isLastPage
                        ? LumiPluginLocalization.string("开始使用", bundle: .module)
                        : LumiPluginLocalization.string("下一步", bundle: .module))
                        .font(.system(size: 13, weight: .semibold))

                    if !isLastPage {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: pages[safePageIndex].iconGradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private func loadPluginSelectionIfNeeded(force: Bool = false) {
        guard force || !hasLoadedPluginSelection else { return }
        selectedPluginIDs = []
        hasLoadedPluginSelection = true
    }

    private func togglePluginSelection(_ pluginID: String) {
        if selectedPluginIDs.contains(pluginID) {
            selectedPluginIDs.remove(pluginID)
        } else {
            selectedPluginIDs.insert(pluginID)
        }
    }

    private func applyPluginSelection() {
    }

    private func completeOnboarding() {
        applyPluginSelection()
        viewModel.complete()
    }

    private var safePageIndex: Int {
        OnboardingPageIndexing.clampedIndex(viewModel.currentStep, pageCount: pages.count)
    }
}

// MARK: - 预览

#Preview("新手引导") {
    OnboardingRootOverlay(content: EmptyView())
}
