import Foundation
import SwiftUI

// MARK: - 通知

private enum OnboardingNotification {
    static let show = Notification.Name("AgentOnboarding.Show")
}

// MARK: - ViewModel

@MainActor
final class OnboardingPluginViewModel: ObservableObject {
    // MARK: - 属性

    @Published var isPresentingOnboarding = false
    @Published var currentStep = 0
    @Published var isTransitioning = false

    private let store: OnboardingPluginStore

    // MARK: - 初始化

    init(store: OnboardingPluginStore = .init(pluginId: "AgentOnboarding")) {
        self.store = store
    }

    // MARK: - 计算属性

    private var hasCompletedOnboarding: Bool {
        store.completed
    }

    // MARK: - 公开方法

    func presentIfNeededOnLaunch() {
        guard !hasCompletedOnboarding else { return }
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        start()
    }

    func start() {
        currentStep = 0
        isPresentingOnboarding = true
    }

    func show(forceReset: Bool) {
        if forceReset {
            store.completed = false
        }
        start()
    }

    func skip() {
        complete()
    }

    func complete() {
        store.completed = true
        isPresentingOnboarding = false
        currentStep = 0
    }

    func nextStep(totalSteps: Int) {
        guard totalSteps > 0 else {
            complete()
            return
        }

        if currentStep >= totalSteps - 1 {
            complete()
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isTransitioning = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.currentStep += 1
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    self.isTransitioning = false
                }
            }
        }
    }

    func previousStep() {
        guard currentStep > 0 else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isTransitioning = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.currentStep -= 1
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.isTransitioning = false
            }
        }
    }
}

// MARK: - Store

final class OnboardingPluginStore {
    // MARK: - 属性

    private let fileManager = FileManager.default
    private let settingsURL: URL
    private let stateFileURL: URL

    // MARK: - 初始化

    init(pluginId: String) {
        let root = AppConfig.getDBFolderURL()
            .appendingPathComponent(pluginId, isDirectory: true)
        self.settingsURL = root.appendingPathComponent("settings", isDirectory: true)
        self.stateFileURL = settingsURL.appendingPathComponent("onboarding_state.plist")
        prepareDirectories()
    }

    // MARK: - 公开方法

    var completed: Bool {
        get { readCompletedFlag() }
        set { writeCompletedFlag(newValue) }
    }

    // MARK: - 私有方法

    private func prepareDirectories() {
        try? fileManager.createDirectory(at: settingsURL, withIntermediateDirectories: true)
    }

    private func readCompletedFlag() -> Bool {
        guard fileManager.fileExists(atPath: stateFileURL.path),
              let data = try? Data(contentsOf: stateFileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any],
              let completed = dict["completed"] as? Bool else {
            return false
        }
        return completed
    }

    private func writeCompletedFlag(_ completed: Bool) {
        let payload: [String: Any] = [
            "completed": completed,
            "updatedAt": Date()
        ]

        guard let data = try? PropertyListSerialization.data(fromPropertyList: payload, format: .binary, options: 0) else {
            return
        }

        let tempURL = settingsURL.appendingPathComponent("onboarding_state.tmp")
        do {
            try data.write(to: tempURL, options: .atomic)
            if fileManager.fileExists(atPath: stateFileURL.path) {
                _ = try? fileManager.replaceItemAt(stateFileURL, withItemAt: tempURL)
            } else {
                try fileManager.moveItem(at: tempURL, to: stateFileURL)
            }
        } catch {
            try? fileManager.removeItem(at: tempURL)
        }
    }
}

// MARK: - RootOverlay

struct OnboardingRootOverlay<Content: View>: View {
    let content: Content

    @StateObject private var viewModel = OnboardingPluginViewModel()

    var body: some View {
        content
            .onAppear {
                viewModel.presentIfNeededOnLaunch()
            }
            .onReceive(NotificationCenter.default.publisher(for: OnboardingNotification.show)) { notification in
                let forceReset = notification.userInfo?["reset"] as? Bool ?? false
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
    @EnvironmentObject private var conversationCreationVM: ConversationCreationVM
    @EnvironmentObject private var pluginVM: PluginVM
    @EnvironmentObject private var themeVM: ThemeVM
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - 页面数据

    private struct OnboardingPage: Identifiable {
        let id = UUID()
        let icon: String
        let iconGradient: [Color]
        let title: String
        let subtitle: String
        let features: [Feature]
        let tip: String?
    }

    private struct Feature {
        let icon: String
        let title: String
        let description: String
    }

    private var pages: [OnboardingPage] {
        [
            OnboardingPage(
                icon: "sparkles",
                iconGradient: [Color.blue, Color.purple],
                title: "欢迎使用 Lumi",
                subtitle: "你的 AI 驱动个人桌面助手",
                features: [
                    Feature(
                        icon: "brain",
                        title: "智能对话",
                        description: "支持本地和云端 LLM，智能处理复杂任务"
                    ),
                    Feature(
                        icon: "hammer.circle",
                        title: "Agent 能力",
                        description: "自动执行文件操作、命令行、Git 等任务"
                    ),
                    Feature(
                        icon: "rectangle.3.group",
                        title: "多会话并行",
                        description: "同时处理多个独立任务，互不干扰"
                    )
                ],
                tip: nil
            ),
            OnboardingPage(
                icon: "rectangle.3.group.bubble.left",
                iconGradient: [Color.green, Color.teal],
                title: "理解界面布局",
                subtitle: "三栏式设计，让工作流清晰高效",
                features: [
                    Feature(
                        icon: "sidebar.left",
                        title: "左侧栏",
                        description: "会话列表 + 项目管理 + 插件面板，快速切换上下文"
                    ),
                    Feature(
                        icon: "text.bubble",
                        title: "中间对话区",
                        description: "提问、查看回复、拖拽添加文件或文件夹作为项目"
                    ),
                    Feature(
                        icon: "sidebar.right",
                        title: "右侧面板",
                        description: "插件提供的工具面板，如搜索、文件浏览等"
                    )
                ],
                tip: "最左侧还有活动栏，可快速切换不同插件面板"
            ),
            OnboardingPage(
                icon: "folder.badge.gearshape",
                iconGradient: [Color.orange, Color.red],
                title: "项目与上下文",
                subtitle: "让 AI 理解你的代码和项目结构",
                features: [
                    Feature(
                        icon: "arrow.down.doc",
                        title: "拖拽添加项目",
                        description: "将文件夹拖入对话区即可设为当前项目"
                    ),
                    Feature(
                        icon: "doc.text.magnifyingglass",
                        title: "智能上下文",
                        description: "自动分析项目结构、代码依赖和文件内容"
                    ),
                    Feature(
                        icon: "chevron.left.slash.chevron.right",
                        title: "代码选区",
                        description: "在编辑器中选中代码，Lumi 会自动获取选中内容"
                    )
                ],
                tip: "最近使用的项目会自动保存，方便快速切换"
            ),
            OnboardingPage(
                icon: "wand.and.stars",
                iconGradient: [Color.purple, Color.pink],
                title: "Agent 工具执行",
                subtitle: "让 AI 不仅仅是聊天，更能真正帮你完成任务",
                features: [
                    Feature(
                        icon: "terminal",
                        title: "命令执行",
                        description: "在安全沙箱中执行 Shell 命令，自动处理权限请求"
                    ),
                    Feature(
                        icon: "doc.badge.gearshape",
                        title: "文件操作",
                        description: "读取、创建、编辑文件，自动保存更改"
                    ),
                    Feature(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Git 集成",
                        description: "查看仓库状态、提交历史，协助代码管理"
                    )
                ],
                tip: "高风险操作会请求你的确认，确保安全可靠"
            ),
            OnboardingPage(
                icon: "puzzlepiece.extension",
                iconGradient: [Color.cyan, Color.blue],
                title: "插件系统",
                subtitle: "通过插件扩展 Lumi 的无限可能",
                features: [
                    Feature(
                        icon: "gearshape.2",
                        title: "内置插件",
                        description: "文件浏览器、最近项目、设置中心等开箱即用"
                    ),
                    Feature(
                        icon: "arrow.up.bin",
                        title: "灵活启用/禁用",
                        description: "在设置中按需管理插件，优化性能和体验"
                    ),
                    Feature(
                        icon: "square.and.arrow.up",
                        title: "Finder 集成",
                        description: "右键菜单快速操作，与 Finder 无缝协作"
                    )
                ],
                tip: "更多插件可在设置中心的「插件」标签页管理"
            ),
            OnboardingPage(
                icon: "gearshape",
                iconGradient: [Color.gray, Color.secondary],
                title: "快速开始",
                subtitle: "完成设置，开始你的 AI 之旅",
                features: [
                    Feature(
                        icon: "cpu",
                        title: "选择模型",
                        description: "配置本地模型或云端 API，选择适合你的 AI 引擎"
                    ),
                    Feature(
                        icon: "paintpalette",
                        title: "自定义主题",
                        description: "深色/浅色模式，多种主题风格随心切换"
                    ),
                    Feature(
                        icon: "plus.circle",
                        title: "创建会话",
                        description: "点击新建按钮或按 ⌘N，开始第一个对话"
                    )
                ],
                tip: "所有设置均可随时在设置中心调整"
            )
        ]
    }

    // MARK: - Body

    var body: some View {
        let page = pages[viewModel.currentStep]
        let isLastPage = viewModel.currentStep == pages.count - 1

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
    }

    // MARK: - 子视图

    /// 背景渐变
    private var backgroundGradient: some View {
        let page = pages[viewModel.currentStep]
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
            Label("新手引导", systemImage: "graduationcap.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer()

            // 步骤指示器
            stepIndicator

            Spacer()

            // 跳过按钮
            Button("跳过") {
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
        HStack(spacing: 6) {
            ForEach(0..<pages.count, id: \.self) { index in
                Capsule()
                    .fill(
                        index == viewModel.currentStep
                            ? pages[viewModel.currentStep].iconGradient[0]
                            : index < viewModel.currentStep
                                ? .secondary.opacity(0.4)
                                : .secondary.opacity(0.15)
                    )
                    .frame(
                        width: index == viewModel.currentStep ? 24 : 8,
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

            // 功能特性列表
            featuresSection(page)
                .padding(.top, 28)

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
                    Label("上一步", systemImage: "chevron.left")
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

            // 主要操作按钮
            if isLastPage {
                HStack(spacing: 10) {
                    // 打开设置按钮
                    Button {
                        NotificationCenter.postOpenSettings()
                        viewModel.complete()
                    } label: {
                        Label("打开设置", systemImage: "gearshape")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.quinary.opacity(0.5))
                    .clipShape(Capsule())

                    // 新建会话按钮
                    Button {
                        Task {
                            await conversationCreationVM.createNewConversation()
                            viewModel.complete()
                        }
                    } label: {
                        Label("新建会话", systemImage: "plus")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.quinary.opacity(0.5))
                    .clipShape(Capsule())
                }
            }

            // 下一步/开始使用按钮
            Button {
                if isLastPage {
                    viewModel.complete()
                } else {
                    viewModel.nextStep(totalSteps: pages.count)
                }
            } label: {
                HStack(spacing: 6) {
                    Text(isLastPage ? "开始使用" : "下一步")
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
                        colors: pages[viewModel.currentStep].iconGradient,
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
}

// MARK: - 预览

#Preview("新手引导") {
    OnboardingRootOverlay(content: EmptyView())
}
