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
            currentStep += 1
        }
    }

    func previousStep() {
        guard currentStep > 0 else { return }
        currentStep -= 1
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
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - 页面数据

    private struct Page: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let subtitle: String
        let highlights: [String]
        let bullets: [String]
    }

    private let pages: [Page] = [
        Page(
            icon: "sparkles",
            title: String(localized: "欢迎使用 Lumi"),
            subtitle: String(localized: "一个为开发者设计的 AI 工作台"),
            highlights: [
                String(localized: "Agent 优先"),
                String(localized: "多会话并行"),
                String(localized: "上下文记忆")
            ],
            bullets: [
                String(localized: "在一个窗口完成提问、执行与复盘"),
                String(localized: "按任务维度沉淀上下文，减少重复沟通"),
                String(localized: "支持多会话并行，互不干扰")
            ]
        ),
        Page(
            icon: "rectangle.3.group.bubble.left",
            title: String(localized: "Agent / App 两种模式"),
            subtitle: String(localized: "根据任务目标选择最合适的工作方式"),
            highlights: [
                String(localized: "复杂任务"),
                String(localized: "单点操作")
            ],
            bullets: [
                String(localized: "Agent 模式：面向复杂任务，支持工具调用与多步骤推理"),
                String(localized: "App 模式：面向插件能力，快速执行单点操作"),
                String(localized: "模式切换后，建议先看顶部提示了解可用能力")
            ]
        ),
        Page(
            icon: "folder.badge.plus",
            title: String(localized: "拖拽添加项目"),
            subtitle: String(localized: "把文件夹拖入消息列表区域即可切换项目"),
            highlights: [
                String(localized: "覆盖提示层"),
                String(localized: "自动切换项目"),
                String(localized: "最近项目同步")
            ],
            bullets: [
                String(localized: "拖拽时会出现毛玻璃提示层，松开即完成添加"),
                String(localized: "仅消息列表区域支持「拖入即设为项目」"),
                String(localized: "输入区域保持原有拖拽行为，不会被覆盖")
            ]
        ),
        Page(
            icon: "keyboard",
            title: String(localized: "快速上手"),
            subtitle: String(localized: "先做 3 件事就能进入工作流"),
            highlights: [
                String(localized: "新建会话"),
                String(localized: "选择模型"),
                String(localized: "随时回看")
            ],
            bullets: [
                String(localized: "新建会话，输入一个真实问题开始"),
                String(localized: "若出现「未选择模型」，在底部模型选择器点选一个模型"),
                String(localized: "在空状态点击「查看新手引导」可随时回看")
            ]
        )
    ]

    // MARK: - Body

    var body: some View {
        let page = pages[viewModel.currentStep]
        let isLastPage = viewModel.currentStep == pages.count - 1

        GlassCard(
            cornerRadius: AppUI.Radius.lg,
            padding: AppUI.Spacing.comfortablePadding,
            showShadow: false,
            borderIntensity: AppUI.Color.adaptive.borderOpacity(for: colorScheme)
        ) {
            VStack(alignment: .leading, spacing: 0) {
                // MARK: 顶部栏

                headerBar

                // MARK: 页面标题区

                VStack(alignment: .leading, spacing: AppUI.Spacing.sm) {
                    Image(systemName: page.icon)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(AppUI.Color.semantic.primary)
                        .glowEffect(
                            color: AppUI.Color.semantic.primary,
                            radius: 10,
                            intensity: AppUI.Color.adaptive.glowIntensity(for: colorScheme)
                        )

                    Text(page.title)
                        .font(AppUI.Typography.title1)
                        .foregroundStyle(AppUI.Color.adaptive.textPrimary(for: colorScheme))

                    Text(page.subtitle)
                        .font(AppUI.Typography.body)
                        .foregroundStyle(AppUI.Color.adaptive.textSecondary(for: colorScheme))
                }
                .padding(.top, AppUI.Spacing.lg)

                // MARK: 高亮标签

                HStack(spacing: AppUI.Spacing.xs) {
                    ForEach(page.highlights, id: \.self) { highlight in
                        AppTag(highlight, style: .accent)
                    }
                }
                .padding(.top, AppUI.Spacing.md)

                // MARK: 要点列表

                VStack(alignment: .leading, spacing: AppUI.Spacing.sm) {
                    ForEach(page.bullets, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: AppUI.Spacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(AppUI.Color.semantic.success)
                                .padding(.top, 2)
                            Text(bullet)
                                .font(AppUI.Typography.body)
                                .foregroundStyle(AppUI.Color.adaptive.textPrimary(for: colorScheme))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, AppUI.Spacing.lg)

                Spacer(minLength: 0)

                // MARK: 底部操作栏

                footerBar(isLastPage: isLastPage)
            }
            .frame(width: 700, height: 500)
        }
        .interactiveDismissDisabled()
    }

    // MARK: - 子视图

    /// 顶部栏：标题 + 跳过按钮
    private var headerBar: some View {
        HStack {
            Label("新手引导", systemImage: "graduationcap")
                .font(AppUI.Typography.bodyEmphasized)
                .foregroundStyle(AppUI.Color.adaptive.textSecondary(for: colorScheme))

            Spacer()

            GlassButton(title: "跳过", style: .ghost) {
                viewModel.skip()
            }
        }
    }

    /// 底部操作栏：指示器 + 导航按钮
    private func footerBar(isLastPage: Bool) -> some View {
        VStack(spacing: 0) {
            GlassDivider()
                .padding(.bottom, AppUI.Spacing.md)

            HStack {
                // 步骤指示器
                stepIndicator

                Spacer()

                // 导航按钮
                HStack(spacing: AppUI.Spacing.sm) {
                    if viewModel.currentStep > 0 {
                        GlassButton(title: "上一步", style: .secondary) {
                            viewModel.previousStep()
                        }
                    }

                    if isLastPage {
                        GlassButton(title: "打开设置", style: .secondary) {
                            NotificationCenter.postOpenSettings()
                        }

                        GlassButton(title: "新建会话", style: .secondary) {
                            Task {
                                await conversationCreationVM.createNewConversation()
                                viewModel.complete()
                            }
                        }
                    }

                    GlassButton(
                        title: isLastPage ? "开始使用" : "下一步",
                        style: .primary
                    ) {
                        viewModel.nextStep(totalSteps: pages.count)
                    }
                }
            }
        }
    }

    /// 步骤指示器
    private var stepIndicator: some View {
        HStack(spacing: AppUI.Spacing.xs) {
            ForEach(0..<pages.count, id: \.self) { index in
                Capsule()
                    .fill(
                        index == viewModel.currentStep
                            ? AppUI.Color.semantic.primary
                            : AppUI.Color.adaptive.textSecondary(for: colorScheme).opacity(0.25)
                    )
                    .frame(
                        width: index == viewModel.currentStep ? 22 : 8,
                        height: 8
                    )
                    .animation(
                        .easeInOut(duration: AppUI.Duration.micro),
                        value: viewModel.currentStep
                    )
            }
        }
    }
}

// MARK: - 预览

#Preview("新手引导") {
    OnboardingRootOverlay(content: EmptyView())
}
